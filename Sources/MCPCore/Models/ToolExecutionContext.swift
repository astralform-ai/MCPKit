//
//  ToolExecutionContext.swift
//  astroform-mcp
//
//  Created by Tony Li on 3/7/25.
//

import Foundation

/// Context information passed to tools during execution to maintain conversation linkage
public struct ToolExecutionContext {
    public let conversationId: UUID?
    public let triggeringMessageId: UUID?
    public let requestId: UUID
    
    public init(conversationId: UUID?, triggeringMessageId: UUID?, requestId: UUID = UUID()) {
        self.conversationId = conversationId
        self.triggeringMessageId = triggeringMessageId
        self.requestId = requestId
    }
}
