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
/// This class is managed internally by `MCPManager`. Use `MCPManager.startLocalServer` to create one.
public final class MCPLocalServer: Sendable {
    private let transport: MCP.Transport
    private let tools: LockedValue<[MCPTool]>
    private let logger: Logging.Logger
    private let serverName: String
    private let serverVersion: String
    private let server: LockedValue<MCP.Server?>

    init(transport: MCP.Transport) throws {
        guard let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String else {
            throw MCPLocalServerError.missingBundleInfo("CFBundleDisplayName")
        }
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            throw MCPLocalServerError.missingBundleInfo("CFBundleShortVersionString")
        }
        self.serverName = name
        self.serverVersion = version
        self.transport = transport
        self.tools = LockedValue([])
        self.logger = Logger(label: "mcpkit.local.server")
        self.server = LockedValue(nil)
    }

    func registerTools(_ newTools: [MCPTool]) {
        tools.withLock { $0.append(contentsOf: newTools) }
        logger.info("Registered \(newTools.count) tools")
    }

    func start() async throws {
        logger.info("Starting MCP server: \(serverName) v\(serverVersion)")

        let currentTools = tools.withLock { $0 }
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
        server.withLock { $0 = mcpServer }

        logger.info("MCP server started with \(currentTools.count) tools")
    }

    func stop() async {
        if let mcpServer = server.withLock({ $0 }) {
            await mcpServer.stop()
            server.withLock { $0 = nil }
            logger.info("MCP server stopped")
        }
    }
}

// MARK: - Thread-safe value wrapper
private final class LockedValue<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
