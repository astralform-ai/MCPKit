//
//  MCPServerConfig.swift
//  Astroform
//
//  Created by Tony Li on 27/6/25.
//

import Foundation
import Observation
import MCP

/// Configuration for remote MCP servers
/// let localServer = MCPServer(name: "Local")
/// let remoteServer = MCPServer(name: "Github",  url: URL(string: "https://api.githubcopilot.com/mcp/"), )
@Observable
public class MCPServerConfig {
    let name: String
    let endpoint: URL?
    let configuration: URLSessionConfiguration?
    let streaming: Bool
    
    public init(
        name: String,
        endpoint: URL?,
        configuration: URLSessionConfiguration?,
        streaming: Bool = true
    ) {
        self.name = name
        self.endpoint = endpoint
        self.configuration = configuration
        self.streaming = streaming
    }
}
