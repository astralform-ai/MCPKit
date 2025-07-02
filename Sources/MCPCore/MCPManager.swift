//
//  MCPManager.swift
//  astroform-mcp
//
//  Created by Tony Li on 3/7/25.
//

import Foundation
import Logging
import MCP
import Observation

@Observable
public class MCPManager {
    private let logger = Logger(label: "astroform.mcp.manager")
    
    public var connections: [MCPConnection] = []
    
    public var enabledTools: [String: Set<String>] = [:]
}
