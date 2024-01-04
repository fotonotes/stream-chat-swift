//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct StreamChatCallSessionEndedEvent: Codable, Hashable {
    public var type: String
    
    public var call: StreamChatCallResponse
    
    public var callCid: String
    
    public var createdAt: String
    
    public var sessionId: String
    
    public init(type: String, call: StreamChatCallResponse, callCid: String, createdAt: String, sessionId: String) {
        self.type = type
        
        self.call = call
        
        self.callCid = callCid
        
        self.createdAt = createdAt
        
        self.sessionId = sessionId
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        
        case call
        
        case callCid = "call_cid"
        
        case createdAt = "created_at"
        
        case sessionId = "session_id"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        
        try container.encode(call, forKey: .call)
        
        try container.encode(callCid, forKey: .callCid)
        
        try container.encode(createdAt, forKey: .createdAt)
        
        try container.encode(sessionId, forKey: .sessionId)
    }
}
