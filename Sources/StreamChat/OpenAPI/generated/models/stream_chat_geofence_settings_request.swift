//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct StreamChatGeofenceSettingsRequest: Codable, Hashable {
    public var names: [String]?
    
    public init(names: [String]?) {
        self.names = names
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case names
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(names, forKey: .names)
    }
}
