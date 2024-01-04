//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct StreamChatPolicy: Codable, Hashable {
    public var createdAt: String
    
    public var name: String
    
    public var owner: Bool
    
    public var priority: Int
    
    public var resources: [String]
    
    public var roles: [String]
    
    public var updatedAt: String
    
    public var action: Int
    
    public init(createdAt: String, name: String, owner: Bool, priority: Int, resources: [String], roles: [String], updatedAt: String, action: Int) {
        self.createdAt = createdAt
        
        self.name = name
        
        self.owner = owner
        
        self.priority = priority
        
        self.resources = resources
        
        self.roles = roles
        
        self.updatedAt = updatedAt
        
        self.action = action
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case createdAt = "created_at"
        
        case name
        
        case owner
        
        case priority
        
        case resources
        
        case roles
        
        case updatedAt = "updated_at"
        
        case action
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(createdAt, forKey: .createdAt)
        
        try container.encode(name, forKey: .name)
        
        try container.encode(owner, forKey: .owner)
        
        try container.encode(priority, forKey: .priority)
        
        try container.encode(resources, forKey: .resources)
        
        try container.encode(roles, forKey: .roles)
        
        try container.encode(updatedAt, forKey: .updatedAt)
        
        try container.encode(action, forKey: .action)
    }
}
