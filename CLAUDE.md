# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**astroform-mcp** is a Swift library that wraps the official MCP (Model Context Protocol) Swift SDK to make it easy for iOS/macOS apps to:

1. **Host MCP tools** - Register your app's functions as MCP tools that AI clients (Claude Desktop, ChatGPT, etc.) can discover and call
2. **Connect to remote MCP servers** - Use 3rd party MCP tools (GitHub, Slack, Filesystem, etc.)

## Build Commands

```bash
swift build          # Build the library
swift test           # Run tests
swift package clean  # Clean build artifacts
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Your iOS/macOS App                                             │
│                                                                 │
│  MCPManager (central orchestrator)                              │
│  ├── localTools: [MCPTool]       ← Your app's functions         │
│  ├── localServer: MCPLocalServer ← Hosts tools for AI clients   │
│  └── connections: [MCPConnection]← Remote MCP servers           │
│                                                                 │
│         │                                    │                  │
│         ▼                                    ▼                  │
│  External AI Client              Remote MCP Servers             │
│  (Claude, ChatGPT)               (GitHub, Slack, etc.)          │
│  calls your tools                you call their tools           │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

| File | Purpose |
|------|---------|
| `MCPTool.swift` | Struct wrapping `MCP.Tool` with an execute handler |
| `MCPLocalServer.swift` | Hosts your tools for external AI clients |
| `MCPConnection.swift` | Client connection to remote MCP servers |
| `MCPManager.swift` | Central manager for local tools + remote connections |

## Usage Examples

### Simple tool (no arguments)
```swift
let ping = MCPTool(name: "ping", description: "Ping the app") { _ in
    return "pong"
}
```

### Tool with arguments
```swift
let playMusic = MCPTool(
    name: "play_music",
    description: "Play a song",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "song": .object(["type": .string("string")])
        ]),
        "required": .array([.string("song")])
    ])
) { args in
    let song = args?["song"]?.stringValue ?? "Unknown"
    return "Now playing: \(song)"
}
```

## Key Design Decisions

- **`MCPTool` is a struct** - wraps `MCP.Tool` + execute closure, not a protocol
- **`inputSchema` defaults to `[:]`** - empty object for no-arg tools (per MCP SDK convention)
- **`client.callTool` returns tuple** - MCP SDK returns `(content, isError)`, not `CallTool.Result`
- **Transport injected by user** - library doesn't create transports; user provides stdio/HTTP/etc.

## Dependencies

- **MCP Swift SDK** (`modelcontextprotocol/swift-sdk` v0.10.0+)
- **swift-log** for logging

## Platform Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.1+
