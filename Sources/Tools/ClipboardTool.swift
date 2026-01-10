//
//  ClipboardTool.swift
//  MCPKit
//
//  Created by MCPKit.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Foundation
import Core
import MCP

/// A tool that provides clipboard (pasteboard) operations.
///
/// This tool allows AI to read from and write to the system clipboard.
///
/// ## Available Operations
/// - `clipboard_read`: Read current clipboard contents
/// - `clipboard_write`: Write text to clipboard
///
/// ## Example Usage
/// ```swift
/// let local = try await manager.startLocalServer {
///     ClipboardTool.tools
/// }
/// try await manager.connect(local)
/// ```
public enum ClipboardTool: MCPToolProvider {
    public static var tools: [MCPTool] {
        [readTool, writeTool]
    }

    /// Tool to read clipboard contents.
    ///
    /// Returns the current text content of the clipboard, if available.
    public static var readTool: MCPTool {
        MCPTool(
            name: "clipboard_read",
            description: "Read the current text content from the clipboard"
        ) { _ in
            #if canImport(UIKit) && !os(macOS)
            let pasteboard = await MainActor.run { UIPasteboard.general }
            if let text = await MainActor.run(body: { pasteboard.string }) {
                return "Clipboard contents: \(text)"
            } else {
                return "Clipboard is empty or does not contain text"
            }
            #elseif canImport(AppKit)
            let pasteboard = NSPasteboard.general
            if let text = pasteboard.string(forType: .string) {
                return "Clipboard contents: \(text)"
            } else {
                return "Clipboard is empty or does not contain text"
            }
            #else
            return "Clipboard not available on this platform"
            #endif
        }
    }

    /// Tool to write text to clipboard.
    ///
    /// Copies the provided text to the system clipboard.
    public static var writeTool: MCPTool {
        MCPTool(
            name: "clipboard_write",
            description: "Write text to the clipboard",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("The text to copy to clipboard")
                    ])
                ]),
                "required": .array([.string("text")])
            ])
        ) { args in
            guard let text = args?["text"]?.stringValue else {
                return "Error: 'text' parameter is required"
            }

            #if canImport(UIKit) && !os(macOS)
            await MainActor.run {
                UIPasteboard.general.string = text
            }
            return "Copied to clipboard: \(text)"
            #elseif canImport(AppKit)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return "Copied to clipboard: \(text)"
            #else
            return "Clipboard not available on this platform"
            #endif
        }
    }
}
