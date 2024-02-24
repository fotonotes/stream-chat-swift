//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

@testable import StreamChat
@testable import StreamChatTestTools
import XCTest

final class MessageEvents_Tests: XCTestCase {
    let messageId: MessageId = "1ff9f6d0-df70-4703-aef0-379f95ad7366"

    var eventDecoder: EventDecoder!

    override func setUp() {
        super.setUp()
        eventDecoder = EventDecoder()
    }

    override func tearDown() {
        super.tearDown()
        eventDecoder = nil
    }

    func test_new() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageNew")
        let event = try eventDecoder.decode(from: json) as? MessageNewEvent
        XCTAssertEqual(event?.user?.id, "broken-waterfall-5")
        XCTAssertEqual(event?.cid, ChannelId(type: .messaging, id: "general").rawValue)
        XCTAssertEqual(event?.message?.id, messageId)
        XCTAssertEqual(event?.createdAt.description, "2020-07-17 13:42:21 +0000")
        XCTAssertEqual(event?.watcherCount, 7)
    }

    func test_new_withMissingFields() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageNew+MissingFields")
        let event = try eventDecoder.decode(from: json) as? MessageNewEvent
        XCTAssertEqual(event?.message?.id, messageId)
        XCTAssertEqual(event?.createdAt.description, "2020-07-21 14:47:57 +0000")
        XCTAssertEqual(event?.watcherCount, 0)
    }

    func test_updated() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageUpdated")
        let event = try eventDecoder.decode(from: json) as? MessageUpdatedEvent
        XCTAssertEqual(event?.user?.id, "broken-waterfall-5")
        XCTAssertEqual(event?.cid, ChannelId(type: .messaging, id: "general").rawValue)
        XCTAssertEqual(event?.message?.id, messageId)
        XCTAssertEqual(event?.createdAt.description, "2020-07-17 13:46:10 +0000")
    }

    func test_messageDeletedEvent_clientSide() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageDeleted")
        let event = try eventDecoder.decode(from: json) as? MessageDeletedEvent
        XCTAssertEqual(event?.user?.id, "broken-waterfall-5")
        XCTAssertEqual(event?.cid, ChannelId(type: .messaging, id: "general").rawValue)
        XCTAssertEqual(event?.message?.id, messageId)
        XCTAssertEqual(event?.createdAt.description, "2020-07-17 13:49:48 +0000")
    }

    func test_messageDeletedEvent_serverSide() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageDeleted+MissingUser")
        let event = try eventDecoder.decode(from: json) as? MessageDeletedEvent
        XCTAssertNil(event?.user)
        XCTAssertEqual(event?.cid, ChannelId(type: .messaging, id: "general").rawValue)
        XCTAssertEqual(event?.message?.id, messageId)
        XCTAssertEqual(event?.createdAt.description, "2020-07-17 13:49:48 +0000")
    }

    func test_messageDeletedEvent_whenNotHardDelete_hardDeleteIsFalse() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageDeleted")
        let event = try eventDecoder.decode(from: json) as? MessageDeletedEvent
        XCTAssertEqual(event?.hardDelete, false)
    }

    func test_messageDeletedEvent_whenHardDelete_hardDeleteIsTrue() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageDeletedHard")
        let event = try eventDecoder.decode(from: json) as? MessageDeletedEvent
        XCTAssertEqual(event?.hardDelete, true)
    }

    func test_read() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageRead")
        let event = try eventDecoder.decode(from: json) as? MessageReadEvent
        XCTAssertEqual(event?.user?.id, "steep-moon-9")
        XCTAssertEqual(event?.cid, ChannelId(type: .messaging, id: "general").rawValue)
        XCTAssertEqual(event?.createdAt.description, "2020-07-17 13:55:56 +0000")
    }

    func test_read_withoutUnreadCount() throws {
        let json = XCTestCase.mockData(fromJSONFile: "MessageRead+MissingUnreadCount")
        let event = try eventDecoder.decode(from: json) as? MessageReadEvent
        XCTAssertEqual(event?.user?.id, "steep-moon-9")
        XCTAssertEqual(event?.cid, ChannelId(type: .messaging, id: "general").rawValue)
        XCTAssertEqual(event?.createdAt.description, "2020-07-17 13:55:56 +0000")
    }
}
