//
//  MCPToolProvider.swift
//  MCPKit
//
//  Protocol for types that provide MCP tools.
//

import Foundation

/// A type that provides MCP tools.
///
/// Conform to this protocol to organize related tools by category.
///
/// ## Usage
///
/// ```swift
/// enum MyTools: MCPToolProvider {
///     static var tools: [MCPTool] {
///         [
///             MCPTool(name: "tool_a", description: "Does A") { _ in "A" },
///             MCPTool(name: "tool_b", description: "Does B") { _ in "B" }
///         ]
///     }
/// }
///
/// let local = try await manager.startLocalServer {
///     MyTools.tools
///     OtherTools.tools
/// }
/// try await manager.connect(local)
/// ```
public protocol MCPToolProvider {
    /// The tools provided by this type.
    static var tools: [MCPTool] { get }
}
