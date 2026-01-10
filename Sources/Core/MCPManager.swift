//
//  MCPManager.swift
//  MCPKit
//
//  Created by Tony Li on 3/7/25.
//

import Foundation
import Logging
import MCP
import Observation
import SwiftUI

/// The central manager for all MCP functionality in your app.
///
/// `MCPManager` is the main entry point for MCPKit. It manages connections to MCP servers,
/// both local (your app's tools) and external (GitHub, Slack, etc.).
///
/// ## Overview
///
/// Use `MCPManager` as a single point of control for all MCP operations. It provides
/// a unified view of all tools from all connections with consistent enable/disable support.
///
/// ## Usage
///
/// ```swift
/// let manager = MCPManager()
///
/// // 1. Start local server and connect
/// let local = try await manager.startLocalServer {
///     DeviceInfoTool.tools
///     ClipboardTool.tools
///     myCustomTools
/// }
/// try await manager.connect(local)
///
/// // 2. Connect to external MCP servers
/// let github = MCPConnection(name: "GitHub", transport: httpTransport)
/// try await manager.connect(github)
///
/// // 3. Toggle tools in SwiftUI
/// ForEach(manager.tools) { tool in
///     Toggle(tool.name, isOn: manager.binding(for: tool))
/// }
///
/// // 4. Call any tool (routes automatically)
/// let result = try await manager.callTool("mcp_github_create_issue", arguments: [...])
/// ```
@Observable
public final class MCPManager: @unchecked Sendable {
    private let logger = Logger(label: "mcpkit.manager")

    /// The local MCP server instance, if started.
    public private(set) var localServer: MCPLocalServer?

    /// All active MCP connections.
    public private(set) var connections: [MCPConnection] = []

    /// Creates a new MCP manager.
    public init() {}

    // MARK: - Local Server

    /// Starts a local MCP server with the given tools and returns a connection to it.
    ///
    /// This method:
    /// 1. Creates an in-memory transport pair
    /// 2. Creates and starts an `MCPLocalServer` with your tools
    /// 3. Returns an `MCPConnection` named "Local" to that server
    ///
    /// You must call `connect()` with the returned connection to make the tools available.
    /// Tool IDs will be prefixed (e.g., `mcp_local_clipboard_read`).
    ///
    /// - Parameter tools: The tools to register with the local server.
    /// - Returns: An `MCPConnection` to the local server.
    ///
    /// ## Example
    /// ```swift
    /// let local = try await manager.startLocalServer {
    ///     DeviceInfoTool.tools
    ///     ClipboardTool.tools
    /// }
    /// try await manager.connect(local)
    /// ```
    public func startLocalServer(@MCPToolsBuilder tools: () -> [MCPTool]) async throws -> MCPConnection {
        let tools = tools()
        // Create linked transport pair
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()

        // Create and start the server
        let server = try MCPLocalServer(transport: serverTransport)
        server.registerTools(tools)
        try await server.start()
        localServer = server

        logger.info("Local server started with \(tools.count) tools")

        // Return connection for user to add
        return try MCPConnection(name: "Local", transport: clientTransport)
    }

    /// Stops the local MCP server and removes its connection.
    public func stopLocalServer() async {
        if let server = localServer {
            await disconnect(name: "Local")
            await server.stop()
            localServer = nil
            logger.info("Local server stopped")
        }
    }

    // MARK: - Connections

    /// Connects to an MCP server and adds it to the manager.
    ///
    /// - Parameter connection: The connection to add.
    public func connect(_ connection: MCPConnection) async throws {
        try await connection.connect()
        connections.append(connection)
        logger.info("Connected: \(connection.name)")
    }

    /// Disconnects and removes a connection by name.
    ///
    /// - Parameter name: The name of the connection.
    public func disconnect(name: String) async {
        if let index = connections.firstIndex(where: { $0.name == name }) {
            let connection = connections[index]
            await connection.disconnect()
            connections.remove(at: index)
            logger.info("Disconnected: \(connection.name)")
        }
    }

    /// Disconnects and removes all connections.
    public func disconnectAll() async {
        for connection in connections {
            await connection.disconnect()
        }
        connections.removeAll()
        await localServer?.stop()
        localServer = nil
    }

    // MARK: - Tools

    /// All tools from all connections (for settings UI).
    public var tools: [MCPTool] {
        connections
            .filter { $0.state == .connected }
            .flatMap { $0.tools }
    }

    /// Enabled tools for AI API (with prefixed names like `mcp_local_clipboard_read`).
    public var enabledTools: [MCP.Tool] {
        connections
            .filter { $0.state == .connected }
            .flatMap { $0.enabledTools }
            .map { tool in
                Tool(
                    name: tool.id,
                    description: tool.description,
                    inputSchema: tool.tool.inputSchema
                )
            }
    }

    /// Returns a binding for a tool's enabled state (for SwiftUI Toggle).
    ///
    /// ## Example
    /// ```swift
    /// ForEach(manager.tools) { tool in
    ///     Toggle(tool.name, isOn: manager.binding(for: tool))
    /// }
    /// ```
    public func binding(for tool: MCPTool) -> Binding<Bool> {
        Binding(
            get: { self.tools.first { $0.id == tool.id }?.isEnabled ?? false },
            set: { enabled in
                for connection in self.connections {
                    connection.setEnabled(enabled, for: tool.id)
                }
            }
        )
    }

    // MARK: - Tool Execution

    /// Calls a tool by its prefixed name (e.g., `mcp_local_clipboard_read`).
    ///
    /// - Parameters:
    ///   - name: The tool's prefixed name from AI response.
    ///   - arguments: Arguments to pass to the tool.
    /// - Returns: The result from the tool execution.
    public func callTool(_ name: String, arguments: [String: MCP.Value]? = nil) async throws -> CallTool.Result {
        // Parse: mcp_{server}_{toolName}
        let parts = name.split(separator: "_", maxSplits: 2)
        guard parts.count == 3, parts[0] == "mcp" else {
            return CallTool.Result(
                content: [.text("Error: Invalid tool name format '\(name)'. Expected 'mcp_{server}_{toolName}'")],
                isError: true
            )
        }

        let serverName = String(parts[1])
        let toolName = String(parts[2])

        // Find connection (case-insensitive match)
        guard let connection = connections.first(where: { $0.name.lowercased() == serverName && $0.state == .connected }) else {
            return CallTool.Result(
                content: [.text("Error: Server '\(serverName)' not found or not connected")],
                isError: true
            )
        }

        // Check if tool is enabled
        guard connection.enabledTools.contains(where: { $0.name == toolName }) else {
            return CallTool.Result(
                content: [.text("Error: Tool '\(toolName)' not found or not enabled in '\(serverName)'")],
                isError: true
            )
        }

        return try await connection.callTool(toolName, arguments: arguments)
    }
}
