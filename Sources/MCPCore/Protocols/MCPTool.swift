//
//  MCPTool.swift
//  Astroform
//
//  Created by Tony Li on 14/6/25.
//

import Foundation
import MCP

/// Protocol for MCP tools that can be executed by the server
public protocol MCPTool: Sendable {
    /// Name of the tool, just a convenient var from tool.name
    var name: String { get }
    
    /// MCP Tool
    var tool: MCP.Tool { get }
    
    /// if tool enabled
    var enabled: Bool { get }
    
    /// Initialize the tool
    init()
    
    /// Execute the tool with the given arguments and context
    /// - Parameters:
    ///   - arguments: The arguments passed to the tool
    ///   - context: Optional execution context with conversation and message IDs
    /// - Returns: The result of the tool execution
    func execute(arguments: [String: MCP.Value]?, context: ToolExecutionContext?) async -> CallTool.Result
}
