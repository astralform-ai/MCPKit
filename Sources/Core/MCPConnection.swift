//
//  MCPConnection.swift
//  MCPKit
//
//  Created by Tony Li on 27/6/25.
//

import Foundation
import MCP
import Observation
import Logging

/// The connection state of an MCP client.
public enum MCPConnectionState: Sendable {
    /// Not connected to any server.
    case disconnected
    /// Currently attempting to connect.
    case connecting
    /// Successfully connected and ready to call tools.
    case connected
}

/// Errors that can occur during MCP connection operations.
public enum MCPConnectionError: Error, LocalizedError {
    /// Required bundle info is missing.
    case missingBundleInfo(String)
    /// The connection to the server failed.
    case connectionFailed(String)
    /// The server has no tools capability.
    case noToolsAvailable
    /// Attempted to call a tool while not connected.
    case notConnected
    /// A tool call failed on the server.
    case toolCallFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingBundleInfo(let key):
            return "Missing required bundle info: \(key)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .noToolsAvailable:
            return "Server has no tools available"
        case .notConnected:
            return "Not connected to server"
        case .toolCallFailed(let message):
            return "Tool call failed: \(message)"
        }
    }
}

/// A client connection to an MCP server.
///
/// This class is managed by `MCPManager`. Use `MCPManager.connect()` to add connections.
///
/// - Note: This class is `@MainActor` isolated to ensure UI-bound state (`state`, `tools`)
///   is always accessed from the main thread, making it safe to use with SwiftUI.
@Observable
@MainActor
public final class MCPConnection {
    /// A unique identifier for this connection.
    public let id: UUID

    /// A human-readable name for this connection (e.g., "Local", "GitHub", "Slack").
    public let name: String

    /// The current connection state.
    public private(set) var state: MCPConnectionState = .disconnected

    /// All tools from this server, wrapped as `MCPTool`.
    ///
    /// Each tool has `isEnabled` which can be toggled. Use ``enabledTools`` to
    /// get only enabled tools, or access this directly for UI display.
    public private(set) var tools: [MCPTool] = []

    /// Tools that are currently enabled.
    ///
    /// Use this for AI tool lists. For settings UI, use ``tools`` to show all with toggles.
    public var enabledTools: [MCPTool] {
        tools.filter { $0.isEnabled }
    }

    /// The name reported by the server (available after connection).
    public private(set) var serverName: String?

    /// The version reported by the server (available after connection).
    public private(set) var serverVersion: String?

    private let client: MCP.Client
    private let transport: MCP.Transport
    private let logger: Logger

    /// Creates a connection to an MCP server.
    ///
    /// The connection is not established until you call ``connect()``.
    ///
    /// - Parameters:
    ///   - name: A human-readable name for this connection (e.g., "Local", "GitHub").
    ///   - transport: The transport to use for communication:
    ///     - `InMemoryTransport` for local in-process servers
    ///     - `HTTPClientTransport` for remote HTTP servers
    ///     - `StdioTransport` for subprocess servers
    public init(name: String, transport: MCP.Transport) throws {
        // Try CFBundleDisplayName first, then fall back to CFBundleName
        guard let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String else {
            throw MCPConnectionError.missingBundleInfo("CFBundleDisplayName or CFBundleName")
        }
        // Try CFBundleShortVersionString first, then fall back to CFBundleVersion
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            throw MCPConnectionError.missingBundleInfo("CFBundleShortVersionString or CFBundleVersion")
        }

        self.id = UUID()
        self.name = name
        self.transport = transport
        self.logger = Logger(label: "mcpkit.connection.\(name)")
        self.client = Client(
            name: appName,
            version: appVersion
        )
    }

    func connect() async throws {
        guard state == .disconnected else { return }

        state = .connecting
        logger.info("Connecting to \(name)...")

        do {
            let result = try await client.connect(transport: transport)

            serverName = result.serverInfo.name
            serverVersion = result.serverInfo.version

            guard result.capabilities.tools != nil else {
                await client.disconnect()
                state = .disconnected
                throw MCPConnectionError.noToolsAvailable
            }

            state = .connected

            // Fetch tools and wrap as MCPTool with prefixed ID
            let rawTools = try await fetchAllTools()
            tools = rawTools.map { tool in
                MCPTool(
                    tool: tool,
                    connectionName: name
                )
            }

            // Subscribe to tool list changes
            if result.capabilities.tools?.listChanged == true {
                // Capture connection name for use in notification handler
                let connectionName = self.name
                await client.onNotification(ToolListChangedNotification.self) { [weak self] _ in
                    guard let self else { return }
                    do {
                        let newTools = try await self.fetchAllTools()
                        // Switch to MainActor for state mutation
                        await MainActor.run {
                            // Preserve enabled state when refreshing
                            let disabledNames = Set(self.tools.filter { !$0.isEnabled }.map { $0.name })
                            self.tools = newTools.map { tool in
                                MCPTool(
                                    tool: tool,
                                    connectionName: connectionName,
                                    isEnabled: !disabledNames.contains(tool.name)
                                )
                            }
                            self.logger.info("Tool list updated: \(self.tools.count) tools")
                        }
                    } catch {
                        self.logger.error("Failed to refresh tools: \(error.localizedDescription)")
                    }
                }
            }

            logger.info("Connected to \(serverName ?? name) with \(tools.count) tools")

        } catch {
            state = .disconnected
            throw MCPConnectionError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() async {
        guard state == .connected else { return }
        await client.disconnect()
        state = .disconnected
        tools = []
        logger.info("Disconnected from \(name)")
    }

    public func setEnabled(_ enabled: Bool, for toolId: String) {
        if let index = tools.firstIndex(where: { $0.id == toolId }) {
            tools[index].isEnabled = enabled
        }
    }

    func callTool(_ name: String, arguments: [String: MCP.Value]? = nil) async throws -> CallTool.Result {
        guard state == .connected else {
            throw MCPConnectionError.notConnected
        }

        logger.debug("Calling tool: \(name)")

        do {
            let (content, isError) = try await client.callTool(name: name, arguments: arguments)
            return CallTool.Result(content: content, isError: isError)
        } catch {
            throw MCPConnectionError.toolCallFailed(error.localizedDescription)
        }
    }

    /// Fetches all tools from the server with pagination support.
    nonisolated private func fetchAllTools() async throws -> [MCP.Tool] {
        var allTools: [MCP.Tool] = []
        var cursor: String? = nil

        repeat {
            let (tools, nextCursor) = try await client.listTools(cursor: cursor)
            allTools.append(contentsOf: tools)
            cursor = nextCursor
        } while cursor != nil

        return allTools
    }
}
