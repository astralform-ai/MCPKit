//
//  MCPConnection.swift
//  Astroform
//
//  Created by Tony Li on 27/6/25.
//

import Foundation
import MCP
import Observation
import Logging

public enum MCPConnectionError: Swift.Error, LocalizedError {
    case missingParamenters(Logger, String)
    case lackCapabilities(Logger, String)
    case connectionFailed(Logger, String)
    
    public var errorDescription: String? {
        switch self {
        case .missingParamenters(let logger, let message):
            logger.error("❌ Missing compulsory parameters: \(message)")
            return "❌ Missing compulsory parameters: \(message)"
        case .lackCapabilities(let logger, let message):
            logger.error("❌ Server issues: \(message)")
            return "❌ Server issues: \(message)"
        case .connectionFailed(let logger, let error):
            logger.error("❌ Failed to connect to MCP server: \(error)")
            return "❌ Failed to connect to MCP server: \(error)"
        }
    }
}

public enum MCPConnectionState {
    case idle
    case connecting
    case connected
}

/// MCP Connection handler
@Observable
public class MCPConnection: @unchecked Sendable {
    // meta
    public let id: UUID
    private let logger = Logger(label: "astroform.mcp.connection")
    
    // connection essentials
    private let client: MCP.Client
    private var transport: MCP.Transport
    
    // connection state
    public private(set) var state: MCPConnectionState
    
    // Server Meta Info, will set value after connected
    private var serverInfo: Server.Info?
    private var serverCapabilities: Server.Capabilities?
    private var serverProtocolVersion: String?
    private var serverInstructions: String?
    
    // mcp tools
    public private(set) var availableTools: [MCP.Tool] = []
    
    public init (
        transport: MCP.Transport
    ) throws {
        self.id = UUID()
        
        self.client = Client(
            name: "Astroform_MCP_Client_\(id.uuidString)",
            version: "1.0.0"
        )
        
        self.transport = transport
        self.state = .idle
    }
    
    // connect
    public func connect() async throws {
        
        state = .connecting
        
        do {
            // Connect to the server
            let result = try await client.connect(transport: transport)
            
            guard let toolsResult = result.capabilities.tools else {
                // instantly disconnect because this mcp server no tools found.
                await client.disconnect()
                state = .idle
                throw MCPConnectionError.lackCapabilities(logger, "💀 This server does not has any tools, disconnect automatically.")
            }
            
            // until reach here, we secure to set state to connected
            state = .connected
            
            // Store meta info
            serverInfo = result.serverInfo
            serverCapabilities = result.capabilities
            serverProtocolVersion = result.protocolVersion
            serverInstructions = result.instructions
            
            // ToolListChangedNotification observer if server support listChanged observer
            if toolsResult.listChanged == true {
                await client.onNotification(ToolListChangedNotification.self) { [weak self] notification in
                    guard let self = self else {
                        return
                    }
                    self.availableTools = try await self.getTools(client: self.client)
                    // logging
                    let nameList = self.availableTools.map {
                        "\($0.name)"
                    }.joined(separator: ",")
                    self.logger.info("✨ New tools list updated.", metadata: [
                        "toolsList": "\(nameList)"
                    ])
                }
            }
            
            // assign to avaiableTools
            availableTools = try await getTools(client: client)

            // log mcp server information
            logger.info("✅ Successfully connected to \(result.serverInfo.name)(\(result.serverInfo.version)) with \(availableTools.count) tools")
            
        } catch {
            // reset connection state to idle
            state = .idle
            // get error info
            let error = error.localizedDescription
            throw MCPConnectionError.connectionFailed(logger, error)
        }
    }
    
    // disconnect
    func disconnect() async {
        await client.disconnect()
        state = .idle
    }
    
    // get mcp tools from server, incase the list is super long, there is a pagination support.
    private func getTools(client: MCP.Client) async throws -> [MCP.Tool] {
        var allTools: [MCP.Tool] = []
        var currentCursor: String? = nil
        repeat {
            let (batchTools, nextCursor) = try await client.listTools(cursor: currentCursor)
            allTools.append(contentsOf: batchTools)
            currentCursor = nextCursor
        } while currentCursor != nil
        return allTools
    }
}
