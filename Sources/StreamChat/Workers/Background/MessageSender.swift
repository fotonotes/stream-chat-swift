//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

/// Observers the storage for messages pending send and sends them.
///
/// Sending of the message has the following phases:
///     1. When a message with `.pending` state local state appears in the db, the sender eques it in the sending queue for the
///     channel the message belongs to.
///     2. The pending messages are send one by one order by their `locallyCreatedAt` value ascending.
///     3. When the message is being sent, its local state is changed to `.sending`
///     4. If the operation is successful, the local state of the message is changed to `nil`. If the operation fails, the local
///     state of is changed to `sendingFailed`.
///
// TODO:
/// - Message send retry
/// - Start sending messages when connection status changes (offline -> online)
///
class MessageSender: Worker {
    /// Because we need to be sure messages for every channel are sent in the correct order, we create a sending queue for
    /// every cid. These queues can send messages in parallel.
    @Atomic private var sendingQueueByCid: [ChannelId: MessageSendingQueue] = [:]
    // Any because CheckedContinuation<Void, Error> requires iOS 13
    private var continuations = [MessageId: Any]()
    
    private lazy var observer = ListDatabaseObserver<MessageDTO, MessageDTO>(
        context: self.database.backgroundReadOnlyContext,
        fetchRequest: MessageDTO
            .messagesPendingSendFetchRequest(),
        itemCreator: { $0 }
    )

    private let sendingDispatchQueue: DispatchQueue = .init(
        label: "co.getStream.ChatClient.MessageSenderQueue",
        qos: .userInitiated,
        attributes: [.concurrent]
    )
    
    /// Notifies when the message queue has finished processing the message.
    var didProcessMessage: ((MessageId, Result<ChatMessage, MessageRepositoryError>) -> Void)?

    let messageRepository: MessageRepository
    let eventsNotificationCenter: EventNotificationCenter

    init(
        messageRepository: MessageRepository,
        eventsNotificationCenter: EventNotificationCenter,
        database: DatabaseContainer,
        apiClient: APIClient
    ) {
        self.messageRepository = messageRepository
        self.eventsNotificationCenter = eventsNotificationCenter
        super.init(database: database, apiClient: apiClient)
        // We need to initialize the observer synchronously
        _ = observer

        // The rest can be done on a background queue
        sendingDispatchQueue.async { [weak self] in
            self?.observer.onChange = { self?.handleChanges(changes: $0) }
            do {
                try self?.observer.startObserving()

                // Send the existing unsent message first. We can simulate callback from the observer and ignore
                // the index path completely.
                if let changes = self?.observer.items.map({ ListChange.insert($0, index: .init(item: 0, section: 0)) }) {
                    self?.handleChanges(changes: changes)
                }
                self?.database.write {
                    $0.rescueMessagesStuckInSending()
                }
            } catch {
                log.error("Failed to start MessageSender worker. \(error)")
            }
        }
    }

    func handleChanges(changes: [ListChange<MessageDTO>]) {
        // Convert changes to a dictionary of requests by their cid
        var newRequests: [ChannelId: [MessageSendingQueue.SendRequest]] = [:]
        changes.forEach { change in
            switch change {
            case .insert(let dto, index: _), .update(let dto, index: _):
                database.backgroundReadOnlyContext.performAndWait {
                    guard let cid = dto.channel.map({ try? ChannelId(cid: $0.cid) }) else {
                        log.error("Skipping sending of the message \(dto.id) because the channel info is missing.")
                        return
                    }
                    // Create the array if it didn't exist
                    guard let cid = cid else { return }
                    newRequests[cid] = newRequests[cid] ?? []
                    newRequests[cid]!.append(.init(
                        messageId: dto.id,
                        createdLocallyAt: (dto.locallyCreatedAt ?? dto.createdAt).bridgeDate
                    ))
                }
            case .move, .remove:
                break
            }
        }

        // If there are requests, add them to proper queues
        guard !newRequests.isEmpty else { return }

        _sendingQueueByCid.mutate { sendingQueueByCid in
            newRequests.forEach { cid, requests in
                if sendingQueueByCid[cid] == nil {
                    let messageSendingQueue = MessageSendingQueue(
                        messageRepository: self.messageRepository,
                        eventsNotificationCenter: self.eventsNotificationCenter,
                        dispatchQueue: sendingDispatchQueue
                    )
                    sendingQueueByCid[cid] = messageSendingQueue
                    
                    if #available(iOS 13.0, *) {
                        messageSendingQueue.delegate = self
                    }
                }

                sendingQueueByCid[cid]?.scheduleSend(requests: requests)
            }
        }
    }
}

// MARK: - Chat State Layer

@available(iOS 13.0, *)
extension MessageSender {
    func waitForAPIRequest(messageId: MessageId) async throws -> ChatMessage {
        try await withCheckedThrowingContinuation { continuation in
            registerContinuation(forMessage: messageId, continuation: continuation)
        }
    }
    
    func registerContinuation(forMessage messageId: MessageId, continuation: CheckedContinuation<ChatMessage, Error>) {
        sendingDispatchQueue.async(flags: .barrier) {
            self.continuations[messageId] = continuation
        }
    }
    
    func completeContinuation(for messageId: MessageId, with result: Result<ChatMessage, MessageRepositoryError>) {
        sendingDispatchQueue.async(flags: .barrier) {
            guard let continuation = self.continuations.removeValue(forKey: messageId) as? CheckedContinuation<ChatMessage, Error> else { return }
            continuation.resume(with: result)
        }
    }
}

extension MessageSender: MessageSendingQueueDelegate {
    fileprivate func messageSendingQueue(
        _ queue: MessageSendingQueue,
        didProcess messageId: MessageId,
        result: Result<ChatMessage, MessageRepositoryError>
    ) {
        if #available(iOS 13.0, *) {
            completeContinuation(for: messageId, with: result)
        }
        didProcessMessage?(messageId, result)
    }
}

private protocol MessageSendingQueueDelegate: AnyObject {
    func messageSendingQueue(_ queue: MessageSendingQueue, didProcess messageId: MessageId, result: Result<ChatMessage, MessageRepositoryError>)
}

/// This objects takes care of sending messages to the server in the order they have been enqueued.
private class MessageSendingQueue {
    let messageRepository: MessageRepository
    let eventsNotificationCenter: EventNotificationCenter
    let dispatchQueue: DispatchQueue
    weak var delegate: MessageSendingQueueDelegate?

    init(
        messageRepository: MessageRepository,
        eventsNotificationCenter: EventNotificationCenter,
        dispatchQueue: DispatchQueue
    ) {
        self.messageRepository = messageRepository
        self.eventsNotificationCenter = eventsNotificationCenter
        self.dispatchQueue = dispatchQueue
    }

    /// We use Set because the message Id is the main identifier. Thanks to this, it's possible to schedule message for sending
    /// multiple times without having to worry about that.
    @Atomic private(set) var requests: Set<SendRequest> = []

    /// Schedules sending of the message. All already scheduled messages with `createdLocallyAt` older than these ones will
    /// be sent first.
    func scheduleSend(requests: [SendRequest]) {
        var wasEmpty: Bool = false
        _requests.mutate { mutableRequests in
            wasEmpty = mutableRequests.isEmpty
            mutableRequests.formUnion(requests)
        }

        if wasEmpty {
            sendNextMessage()
        }
    }

    /// Gets the oldest message from the queue and tries to send it.
    private func sendNextMessage() {
        dispatchQueue.async { [weak self] in
            // Sort the messages and send the oldest one
            // If this proves to be a bottleneck in the future, we might
            // switch to using a custom `OrderedSet`
            guard let sortedRequests = self?.requests.sorted(by: { $0.createdLocallyAt < $1.createdLocallyAt }) else { return }
            guard let request = sortedRequests.first else { return }

            self?.messageRepository.sendMessage(with: request.messageId) { [weak self] result in
                // If we failed to send a message we must fail all the next messages as well for preserving the message order
                if let error = result.error, case .failedToSendMessage = error {
                    sortedRequests.forEach { self?.handleSendRequestResult(request: $0, result: result) }
                } else {
                    self?.handleSendRequestResult(request: request, result: result)
                }
                self?.sendNextMessage()
            }
        }
    }

    private func handleSendRequestResult(request: MessageSendingQueue.SendRequest, result: Result<ChatMessage, MessageRepositoryError>) {
        _requests.mutate { $0.remove(request) }
        if let error = result.error {
            switch error {
            case .messageDoesNotExist,
                 .messageNotPendingSend,
                 .messageDoesNotHaveValidChannel:
                let event = NewMessageErrorEvent(messageId: request.messageId, error: error)
                eventsNotificationCenter.process(event)
            case let .failedToSendMessage(error):
                let event = NewMessageErrorEvent(messageId: request.messageId, error: error)
                eventsNotificationCenter.process(event)
            }
        }
        delegate?.messageSendingQueue(self, didProcess: request.messageId, result: result)
    }
}

extension MessageSendingQueue {
    struct SendRequest: Hashable {
        let messageId: MessageId
        let createdLocallyAt: Date

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.messageId == rhs.messageId
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(messageId)
        }
    }
}
