//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

public extension ChatClient {
    func pollVoteListController(query: PollVoteListQuery) -> PollVoteListController {
        .init(query: query, client: self)
    }
}

/// `ChatReactionListController` uses this protocol to communicate changes to its delegate.
public protocol PollVoteListControllerDelegate: DataControllerStateDelegate {
    /// The controller changed the list of observed reactions.
    ///
    /// - Parameters:
    ///   - controller: The controller emitting the change callback.
    ///   - changes: The change to the list of reactions.
    func controller(
        _ controller: PollVoteListController,
        didChangeVotes changes: [ListChange<PollVote>]
    )
}

/// A controller which allows querying and filtering the reactions of a message.
public class PollVoteListController: DataController, DelegateCallable, DataStoreProvider {
    /// The query specifying and filtering the list of users.
    public let query: PollVoteListQuery

    /// The `ChatClient` instance this controller belongs to.
    public let client: ChatClient

    /// The total reactions of the message the controller represents.
    ///
    /// To observe changes of the reactions, set your class as a delegate of this controller or use the provided
    /// `Combine` publishers.
    public var votes: LazyCachedMapCollection<PollVote> {
        startPollVotesListObserverIfNeeded()
        return pollVotesObserver.items
    }

    /// The worker used to fetch the remote data and communicate with servers.
    private lazy var worker: PollsRepository = environment.pollsRepositoryBuilder(
        client.databaseContainer,
        client.apiClient
    )

    /// Set the delegate of `ReactionListController` to observe the changes in the system.
    public weak var delegate: PollVoteListControllerDelegate? {
        get { multicastDelegate.mainDelegate }
        set { multicastDelegate.set(mainDelegate: newValue) }
    }

    /// A type-erased delegate.
    var multicastDelegate: MulticastDelegate<PollVoteListControllerDelegate> = .init() {
        didSet {
            stateMulticastDelegate.set(mainDelegate: multicastDelegate.mainDelegate)
            stateMulticastDelegate.set(additionalDelegates: multicastDelegate.additionalDelegates)

            // After setting delegate local changes will be fetched and observed.
            startPollVotesListObserverIfNeeded()
        }
    }

    /// Used for observing the database for changes.
    private(set) lazy var pollVotesObserver: ListDatabaseObserverWrapper<PollVote, PollVoteDTO> = {
        let request = PollVoteDTO.pollVoteListFetchRequest(query: query)

        let observer = self.environment.createPollListDatabaseObserver(
            StreamRuntimeCheck._isBackgroundMappingEnabled,
            client.databaseContainer,
            request,
            { try $0.asModel() }
        )

        observer.onDidChange = { [weak self] changes in
            self?.delegateCallback { [weak self] in
                guard let self = self else {
                    log.warning("Callback called while self is nil")
                    return
                }

                $0.controller(self, didChangeVotes: changes)
            }
        }

        return observer
    }()

    var _basePublishers: Any?
    /// An internal backing object for all publicly available Combine publishers. We use it to simplify the way we expose
    /// publishers. Instead of creating custom `Publisher` types, we use `CurrentValueSubject` and `PassthroughSubject` internally,
    /// and expose the published values by mapping them to a read-only `AnyPublisher` type.
    @available(iOS 13, *)
    var basePublishers: BasePublishers {
        if let value = _basePublishers as? BasePublishers {
            return value
        }
        _basePublishers = BasePublishers(controller: self)
        return _basePublishers as? BasePublishers ?? .init(controller: self)
    }
    
    private let eventsController: EventsController
    private let pollsRepository: PollsRepository
    private let environment: Environment

    /// Creates a new `UserListController`.
    ///
    /// - Parameters:
    ///   - query: The query used for filtering the reactions.
    ///   - client: The `Client` instance this controller belongs to.
    init(query: PollVoteListQuery, client: ChatClient, environment: Environment = .init()) {
        self.client = client
        self.query = query
        self.environment = environment
        eventsController = client.eventsController()
        pollsRepository = client.pollsRepository
        super.init()
        eventsController.delegate = self
    }

    override public func synchronize(_ completion: ((_ error: Error?) -> Void)? = nil) {
        startPollVotesListObserverIfNeeded()

        worker.queryPollVotes(query: query) { result in
            if let error = result.error {
                self.state = .remoteDataFetchFailed(ClientError(with: error))
            } else {
                self.state = .remoteDataFetched
            }
            self.callback { completion?(result.error) }
        }
    }

    /// If the `state` of the controller is `initialized`, this method calls `startObserving` on the
    /// `reactionListObserver` to fetch the local data and start observing the changes. It also changes
    /// `state` based on the result.
    private func startPollVotesListObserverIfNeeded() {
        guard state == .initialized else { return }
        do {
            try pollVotesObserver.startObserving()
            state = .localDataFetched
        } catch {
            state = .localDataFetchFailed(ClientError(with: error))
            log.error("Failed to perform fetch request with error: \(error). This is an internal error.")
        }
    }
}

// MARK: - Actions

public extension PollVoteListController {
    /// Loads more reactions.
    ///
    /// - Parameters:
    ///   - limit: Limit for the page size.
    ///   - completion: The completion callback.
    func loadMoreVotes(
        limit: Int = 25,
        completion: ((Error?) -> Void)? = nil
    ) {
        var updatedQuery = query
        updatedQuery.pagination = Pagination(pageSize: limit, offset: votes.count)
        worker.queryPollVotes(query: updatedQuery) { result in
            self.callback { completion?(result.error) }
        }
    }
}

extension PollVoteListController {
    struct Environment {
        var pollsRepositoryBuilder: (
            _ database: DatabaseContainer,
            _ apiClient: APIClient
        ) -> PollsRepository = PollsRepository.init

        var createPollListDatabaseObserver: (
            _ isBackgroundMappingEnabled: Bool,
            _ database: DatabaseContainer,
            _ fetchRequest: NSFetchRequest<PollVoteDTO>,
            _ itemCreator: @escaping (PollVoteDTO) throws -> PollVote
        )
            -> ListDatabaseObserverWrapper<PollVote, PollVoteDTO> = {
                ListDatabaseObserverWrapper(isBackground: $0, database: $1, fetchRequest: $2, itemCreator: $3)
            }
    }
}

extension PollVoteListController: EventsControllerDelegate {
    public func eventsController(_ controller: EventsController, didReceiveEvent event: any Event) {
        if let event = event as? PollVoteCastedEvent {
            let vote = event.vote
            if vote.isAnswer == true && query.pollId == vote.pollId && query.optionId == nil {
                pollsRepository.link(pollVote: vote, to: query)
            }
        }
    }
}
