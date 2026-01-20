//
//  MCPLocalServer.swift
//  MCPKit
//
//  Created by Tony Li on 27/6/25.
//

import Foundation
import Logging
import MCP

/// Errors that can occur when creating an MCP local server.
public enum MCPLocalServerError: Error, LocalizedError {
    /// Required bundle info is missing.
    case missingBundleInfo(String)

    public var errorDescription: String? {
        switch self {
        case .missingBundleInfo(let key):
            return "Missing required bundle info: \(key)"
        }
    }
}

/// An MCP server that hosts your app's tools.
///
/// This actor is managed internally by `MCPManager`. Use `MCPManager.startLocalServer` to create one.
///
/// - Note: This is an actor to ensure thread-safe access to mutable state (tools, server).
public actor MCPLocalServer {
    private let transport: MCP.Transport
    private var tools: [MCPTool] = []
    private let logger: Logging.Logger
    private let serverName: String
    private let serverVersion: String
    private var server: MCP.Server?

    init(transport: MCP.Transport) throws {
        // Try CFBundleDisplayName first, then fall back to CFBundleName
        guard let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String else {
            throw MCPLocalServerError.missingBundleInfo("CFBundleDisplayName or CFBundleName")
        }
        // Try CFBundleShortVersionString first, then fall back to CFBundleVersion
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            throw MCPLocalServerError.missingBundleInfo("CFBundleShortVersionString or CFBundleVersion")
        }
        self.serverName = name
        self.serverVersion = version
        self.transport = transport
        self.logger = Logger(label: "mcpkit.local.server")
    }

    /// Registers tools with the local MCP server.
    ///
    /// ## Tool ID vs Name
    /// Each `MCPTool` has both an `id` and a `name`:
    /// - **`id`**: Used for MCPKit identification and routing (e.g., `"mcp_appname_todo_add"`)
    /// - **`name`**: Used for MCP protocol communication (e.g., `"todo_add"`)
    ///
    /// ## Important
    /// The MCP protocol only transmits `tool.name`, never `tool.id`. When clients
    /// receive tools via MCP, they create their own `id` based on connection name.
    /// Tool lookup in `CallTool` handler uses `tool.name`, not `tool.id`.
    ///
    /// ## Example
    /// ```swift
    /// // Server registers tool
    /// let tool = MCPTool(name: "todo_add", description: "Add a todo")
    /// // Internal: id = "todo_add", name = "todo_add"
    ///
    /// // MCP Protocol transmits only name
    /// ListTools.Result → tools: [Tool(name: "todo_add", ...)]
    ///
    /// // Client creates new MCPTool with its own id
    /// MCPTool(tool: mcpTool, connectionName: "Local")
    /// // Internal: id = "mcp_local_todo_add", name = "todo_add"
    /// ```
    ///
    /// - Parameter newTools: Array of tools to register with the server.
    func registerTools(_ newTools: [MCPTool]) {
        tools.append(contentsOf: newTools)
        logger.info("Registered \(newTools.count) tools")
    }

    func start() async throws {
        logger.info("Starting MCP server: \(serverName) v\(serverVersion)")

        // Capture tools for use in handlers (actors are re-entrant safe)
        let currentTools = tools
        let logger = self.logger

        let mcpServer = MCP.Server(
            name: serverName,
            version: serverVersion,
            capabilities: Server.Capabilities(
                tools: .init(listChanged: true)
            )
        )

        // Handle ListTools request
        await mcpServer.withMethodHandler(ListTools.self) { _ in
            let toolDefs = currentTools.map { $0.tool }
            return ListTools.Result(tools: toolDefs)
        }

        // Handle CallTool request
        await mcpServer.withMethodHandler(CallTool.self) { params in
            let name = params.name
            let arguments = params.arguments

            logger.debug("Tool call: \(name)")

            // Find the tool
            guard let tool = currentTools.first(where: { $0.name == name }) else {
                logger.warning("Unknown tool requested: \(name)")
                return CallTool.Result(
                    content: [.text("Error: Unknown tool '\(name)'")],
                    isError: true
                )
            }

            // Check if enabled
            guard tool.isEnabled else {
                logger.warning("Disabled tool requested: \(name)")
                return CallTool.Result(
                    content: [.text("Error: Tool '\(name)' is disabled")],
                    isError: true
                )
            }

            // Execute the tool
            return await tool.execute(arguments: arguments)
        }

        // Start the server
        try await mcpServer.start(transport: transport)
        server = mcpServer

        logger.info("MCP server started with \(currentTools.count) tools")
    }

    func stop() async {
        if let mcpServer = server {
            await mcpServer.stop()
            server = nil
            logger.info("MCP server stopped")
        }
    }
}
