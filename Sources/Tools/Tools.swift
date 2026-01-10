//
//  Tools.swift
//  MCPKit
//
//  Provides pre-built tools for iOS/macOS apps.
//

import Foundation
import Core

/// Pre-built tools for iOS/macOS apps.
///
/// `Tools` provides ready-to-use MCP tools for common device capabilities.
/// Use these with `MCPManager.startLocalServer` to give AI access to device features.
///
/// ## Available Tools
///
/// - **ClipboardTool**: Read/write pasteboard
/// - **NotificationTool**: Schedule local notifications
/// - **URLOpenerTool**: Open URLs, deep links, settings
/// - **CalendarTool**: Read/create calendar events
///
/// ## Usage
///
/// ### Register all tools
/// ```swift
/// let local = try await manager.startLocalServer {
///     Tools.all
/// }
/// try await manager.connect(local)
/// ```
///
/// ### Register specific tools
/// ```swift
/// let local = try await manager.startLocalServer {
///     ClipboardTool.tools
///     CalendarTool.tools
/// }
/// try await manager.connect(local)
/// ```
public enum Tools {
    /// All available tools.
    ///
    /// This combines tools from all categories:
    /// - Clipboard (read/write)
    /// - Notifications (schedule reminders)
    /// - URL opener (web, deep links, settings)
    /// - Calendar (read/create events)
    ///
    /// ## Example
    /// ```swift
    /// let local = try await manager.startLocalServer {
    ///     Tools.all
    /// }
    /// try await manager.connect(local)
    /// ```
    @MCPToolsBuilder
    public static var all: [MCPTool] {
        ClipboardTool.tools
        NotificationTool.tools
        URLOpenerTool.tools
        CalendarTool.tools
    }
}
