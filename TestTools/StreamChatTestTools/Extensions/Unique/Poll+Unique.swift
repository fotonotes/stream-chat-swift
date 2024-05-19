//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation
@testable import StreamChat

extension Poll {
    static var unique: Poll {
        .init(
            allowAnswers: false,
            allowUserSuggestedOptions: false,
            answersCount: 0,
            createdAt: Date(),
            pollDescription: nil,
            enforceUniqueVote: false,
            id: "123",
            name: "Poll",
            updatedAt: Date(),
            voteCount: 0,
            custom: [:],
            voteCountsByOption: nil,
            isClosed: false,
            maxVotesAllowed: nil,
            votingVisibility: nil,
            createdBy: .mock(id: .unique),
            latestAnswers: [],
            options: [],
            latestVotesByOption: []
        )
    }
}
