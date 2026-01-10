# MCPKit

Swift package for integrating MCP (Model Context Protocol) tools into iOS/macOS apps.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/user/MCPKit.git", from: "1.0.0")
]
```

**Targets:**
- `MCPKit` - Full bundle (Core + Tools)
- `Core` - MCP infrastructure only
- `Tools` - Predefined tools only

## Quick Start

```swift
import MCPKit

let manager = MCPManager()

// Start local server with tools
let local = try await manager.startLocalServer {
    ClipboardTool.tools
    CalendarTool.tools
    NotificationTool.tools
    URLOpenerTool.tools
}
try await manager.connect(local)

// Get tools for AI
let tools = manager.enabledTools  // Send to OpenAI/Claude

// Execute tool call from AI response
let result = try await manager.callTool("mcp_local_clipboard_read")
```

## Predefined Tools

| Tool | Operations |
|------|------------|
| **ClipboardTool** | `clipboard_read`, `clipboard_write` |
| **NotificationTool** | `notification_schedule`, `notification_request_permission` |
| **URLOpenerTool** | `url_open` |
| **CalendarTool** | `calendar_list_events`, `calendar_create_event` |

## Custom Tools

```swift
let local = try await manager.startLocalServer {
    // Use predefined tools
    Tools.all

    // Add custom tools
    MCPTool(name: "my_tool", description: "Does something") { args in
        return "Result"
    }
}
```

## SwiftUI Integration

```swift
// Toggle tools in settings
ForEach(manager.tools) { tool in
    Toggle(tool.name, isOn: manager.binding(for: tool))
}
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.1+
