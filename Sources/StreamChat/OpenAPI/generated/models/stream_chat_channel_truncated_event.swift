//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct StreamChatChannelTruncatedEvent: Codable, Hashable {
    public var channelId: String
    
    public var channelType: String
    
    public var cid: String
    
    public var createdAt: String
    
    public var type: String
    
    public var channel: StreamChatChannelResponse?
    
    public init(channelId: String, channelType: String, cid: String, createdAt: String, type: String, channel: StreamChatChannelResponse?) {
        self.channelId = channelId
        
        self.channelType = channelType
        
        self.cid = cid
        
        self.createdAt = createdAt
        
        self.type = type
        
        self.channel = channel
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case channelId = "channel_id"
        
        case channelType = "channel_type"
        
        case cid
        
        case createdAt = "created_at"
        
        case type
        
        case channel
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(channelId, forKey: .channelId)
        
        try container.encode(channelType, forKey: .channelType)
        
        try container.encode(cid, forKey: .cid)
        
        try container.encode(createdAt, forKey: .createdAt)
        
        try container.encode(type, forKey: .type)
        
        try container.encode(channel, forKey: .channel)
    }
}
