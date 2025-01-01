//
// Copyright © 2025 Stream.io Inc. All rights reserved.
//

import Foundation

extension Endpoint {
    static func channelMembers(
        query: ChannelMemberListQuery
    ) -> Endpoint<ChannelMemberListPayload> {
        .init(
            path: .members,
            method: .get,
            queryItems: nil,
            requiresConnectionId: false,
            body: ["payload": query]
        )
    }
}
