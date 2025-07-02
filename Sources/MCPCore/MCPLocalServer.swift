//
//  MCPLocalServer.swift
//  Astroform
//
//  Created by Tony Li on 27/6/25.
//

import Logging
import MCP

class MCPLocalServer: @unchecked Sendable {
    // server transport
    private var transport: MCP.Transport
    private var tools: [any MCPTool]
    private var logger: Logging.Logger
    private var server: MCP.Server?
    
    init(
        transport: MCP.Transport,
        tools: [any MCPTool] = [],
        logger: Logging.Logger = .init(label: "astroform.mcp.server.local")
    ) {
        self.transport = transport
        self.tools = tools
        self.logger = logger
    }
    
    /// start local server
    public func start() async throws {
        
        logger.info("✨ Starting local MCP server")
        
        // Capture tools and logger for sendable closures
        let tools = self.tools
        let logger = self.logger
        
        // Create MCP server with tools capability
        let server = await MCP.Server(
            name: "Astroform",
            version: "1.0.0",
            capabilities: Server.Capabilities(
                tools: .init(listChanged: true) // means server need send notification to client instead of client keep pulling
            )
        ).withMethodHandler(ListTools.self) { _ in
            // register tools here
            let mcpTools = tools.map { $0.tool }
            return ListTools.Result(tools: mcpTools)
        }.withMethodHandler(CallTool.self) { params in
            let name = params.name
            let arguments = params.arguments
            
            if let tool = tools.first(where: { $0.name == name }) {
                return await tool.execute(arguments: arguments, context: nil)
            } else {
                logger.warning("🤷 Unknown local tool requested", metadata: ["tool": "\(name)"])
                let content = Tool.Content.text("Error: Unknown local tool '\(name)'")
                return CallTool.Result(content: [content], isError: true)
            }
        }
        
        // start server
        try await server.start(transport: transport)
        
        // assign server
        self.server = server
        
        logger.info("✅ Local MCP server started successfully")
    }
    
    /// stop local server
    public func stop() async {
        guard let server else {
            return
        }
        await server.stop()
        await transport.disconnect()
    }
    
    /// restart local server incase there is any tool changes
    public func restart() async throws {
        await stop()
        try await start()
    }
}
