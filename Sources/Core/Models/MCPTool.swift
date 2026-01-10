//
//  MCPTool.swift
//  MCPKit
//
//  Created by Tony Li on 14/6/25.
//

import Foundation
import MCP

/// A unified tool type for MCP tools.
///
/// ## Usage
///
/// ### Simple tool (returns String)
/// ```swift
/// MCPTool(name: "ping", description: "Check if responsive") { _ in
///     return "pong"
/// }
/// ```
///
/// ### Tool with arguments
/// ```swift
/// MCPTool(
///     name: "greet",
///     description: "Greet a user",
///     inputSchema: ["type": "object", "properties": ["name": ["type": "string"]], "required": ["name"]]
/// ) { args in
///     let name = args?["name"]?.stringValue ?? "World"
///     return "Hello, \(name)!"
/// }
/// ```
///
/// ### Throwing tool (for operations that can fail)
/// ```swift
/// MCPTool(
///     name: "fetch_data",
///     description: "Fetch data from API",
///     throwingHandler: { args in
///         return try await api.fetchData()
///     }
/// )
/// ```
///
/// ### Full control (for complex responses)
/// ```swift
/// MCPTool(tool: myMCPTool) { args in
///     return CallTool.Result(content: [.text("Result"), .image(data)], isError: false)
/// }
/// ```
public struct MCPTool: Sendable, Identifiable {
    /// A unique identifier for this tool.
    ///
    /// - Server side: Just the tool name (e.g., `"clipboard_read"`)
    /// - Client side: `"mcp_{server}_{toolName}"` (e.g., `"mcp_local_clipboard_read"`)
    public let id: String

    /// The underlying MCP tool definition containing name, description, and input schema.
    public let tool: MCP.Tool

    /// Whether this tool is currently enabled.
    ///
    /// Disabled tools are excluded from available tools and will return an error if called.
    public var isEnabled: Bool

    /// The execution handler. Present for server-side tools, `nil` for client-side references.
    internal let handler: (@Sendable ([String: MCP.Value]?) async -> CallTool.Result)?

    // MARK: - Convenience Accessors

    /// The tool's name.
    public var name: String { tool.name }

    /// The tool's description.
    public var description: String { tool.description ?? "" }

    /// The tool's input schema (JSON Schema format).
    public var inputSchema: MCP.Value { tool.inputSchema }

    // MARK: - Server-side Initializers (for MCPLocalServer)

    /// Creates a tool with full control over the execution result.
    ///
    /// - Parameters:
    ///   - tool: The MCP tool definition.
    ///   - isEnabled: Whether the tool is enabled. Defaults to `true`.
    ///   - handler: The async handler that executes when the tool is called.
    public init(
        _ tool: MCP.Tool,
        isEnabled: Bool = true,
        handler: @escaping @Sendable ([String: MCP.Value]?) async -> CallTool.Result
    ) {
        self.id = tool.name
        self.tool = tool
        self.isEnabled = isEnabled
        self.handler = handler
    }

    /// Creates a tool that returns a text response.
    ///
    /// - Parameters:
    ///   - name: The tool's unique name.
    ///   - description: A description of what the tool does.
    ///   - inputSchema: JSON Schema defining the tool's arguments. Use `["type": "object", "properties": [...], "required": [...]]` format. Defaults to `[:]` (no arguments).
    ///   - handler: Handler that returns a `String` response.
    ///
    /// ## Example
    /// ```swift
    /// let ping = MCPTool(
    ///     name: "ping",
    ///     description: "Check if the app is responsive"
    /// ) { _ in
    ///     return "pong"
    /// }
    /// ```
    public init(
        name: String,
        description: String,
        inputSchema: MCP.Value = [:],
        handler: @escaping @Sendable ([String: MCP.Value]?) async -> String
    ) {
        self.id = name
        self.tool = Tool(name: name, description: description, inputSchema: inputSchema)
        self.isEnabled = true
        self.handler = { args in
            let result = await handler(args)
            return CallTool.Result(content: [.text(result)])
        }
    }

    /// Creates a tool that can throw errors.
    ///
    /// - Parameters:
    ///   - name: The tool's unique name.
    ///   - description: A description of what the tool does.
    ///   - inputSchema: JSON Schema defining the tool's arguments. Use `["type": "object", "properties": [...], "required": [...]]` format. Defaults to `[:]` (no arguments).
    ///   - throwingHandler: Handler that can throw errors.
    ///
    /// ## Example
    /// ```swift
    /// let fetchUser = MCPTool(
    ///     name: "fetch_user",
    ///     description: "Fetch user from database",
    ///     throwingHandler: { args in
    ///         guard let id = args?["id"]?.stringValue else {
    ///             throw MyError.missingId
    ///         }
    ///         return try await database.fetchUser(id: id)
    ///     }
    /// )
    /// ```
    public init(
        name: String,
        description: String,
        inputSchema: MCP.Value = [:],
        throwingHandler: @escaping @Sendable ([String: MCP.Value]?) async throws -> String
    ) {
        self.id = name
        self.tool = Tool(name: name, description: description, inputSchema: inputSchema)
        self.isEnabled = true
        self.handler = { args in
            do {
                let result = try await throwingHandler(args)
                return CallTool.Result(content: [.text(result)])
            } catch {
                return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }
    }

    // MARK: - Client-side Initializer (for MCPConnection)

    /// Creates a tool reference from an MCP server. Used internally by `MCPConnection`.
    ///
    /// - Parameters:
    ///   - tool: The tool definition from the server.
    ///   - connectionName: The name of the connection (e.g., "Local", "GitHub").
    ///   - isEnabled: Whether the tool is enabled. Defaults to `true`.
    internal init(
        tool: MCP.Tool,
        connectionName: String,
        isEnabled: Bool = true
    ) {
        self.id = "mcp_\(connectionName.lowercased())_\(tool.name)"
        self.tool = tool
        self.isEnabled = isEnabled
        self.handler = nil
    }

    public func execute(arguments: [String: MCP.Value]?) async -> CallTool.Result {
        guard let handler else {
            return CallTool.Result(
                content: [.text("Error: No handler for this tool.")],
                isError: true
            )
        }
        return await handler(arguments)
    }
}
