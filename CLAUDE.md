# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `astroform-mcp`, a Swift package that provides an MCP (Model Context Protocol) implementation for iOS apps. The package enables iOS applications to connect to and manage MCP servers, facilitating tool execution and server communication.

## Architecture

### Core Components

- **MCPCore**: Main module containing all MCP functionality
- **MCPManager**: Observable class that manages multiple MCP connections and tracks enabled tools
- **MCPConnection**: Handles individual MCP server connections with state management (idle/connecting/connected)
- **MCPLocalServer**: Local MCP server implementation that can host tools locally
- **MCPTool Protocol**: Defines the interface for MCP tools that can be executed

### Key Design Patterns

- Uses Swift's `@Observable` macro for reactive state management
- Protocol-oriented design with `MCPTool` for extensible tool system
- Async/await throughout for proper concurrency handling
- Comprehensive error handling with custom `MCPConnectionError` types

### Dependencies

- **MCP Swift SDK**: Uses a custom fork from `https://github.com/atom2ueki/swift-sdk.git` (PassthroughTransport branch)
- **Swift Logging**: For structured logging throughout the system
- **Foundation**: Core Swift framework dependencies

## Development Commands

### Building
```bash
swift build
```

### Testing
```bash
swift test
```

### Package Management
```bash
swift package resolve          # Resolve dependencies
swift package update           # Update dependencies
swift package clean            # Clean build artifacts
```

### Platform Requirements
- iOS 17.0+ (as specified in Package.swift)
- Swift 6.1+ (swift-tools-version)

## Key Files to Understand

- `Sources/MCPCore/MCPManager.swift`: Entry point for managing MCP connections
- `Sources/MCPCore/MCPConnection.swift`: Core connection logic and state management
- `Sources/MCPCore/MCPLocalServer.swift`: Local server implementation
- `Sources/MCPCore/Protocols/MCPTool.swift`: Tool protocol definition
- `Package.swift`: Package configuration and dependencies