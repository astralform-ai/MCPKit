//
//  URLOpenerTool.swift
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

/// A tool that opens URLs, including web links, deep links, and system settings.
///
/// This tool allows AI to open URLs in the appropriate app or browser.
///
/// ## Available Operations
/// - `url_open`: Open any URL (web, deep link, tel:, mailto:, app settings)
///
/// ## Example Usage
/// ```swift
/// let local = try await manager.startLocalServer {
///     URLOpenerTool.tools
/// }
/// try await manager.connect(local)
/// ```
public enum URLOpenerTool: MCPToolProvider {
    public static var tools: [MCPTool] {
        [openTool]
    }

    /// Tool to open a URL.
    ///
    /// Opens web links, deep links, phone numbers (tel:), emails (mailto:), or app settings.
    public static var openTool: MCPTool {
        MCPTool(
            name: "url_open",
            description: "Open a URL (web link, deep link, tel:, mailto:, or app settings). Use 'app-settings:' to open the app's settings.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "url": .object([
                        "type": .string("string"),
                        "description": .string("The URL to open. Examples: 'https://apple.com', 'tel:+1234567890', 'mailto:test@example.com', 'app-settings:' for app settings")
                    ])
                ]),
                "required": .array([.string("url")])
            ]),
            throwingHandler: { args in
                guard let urlString = args?["url"]?.stringValue else {
                    throw URLOpenerError.missingURL
                }

                // Handle special app-settings URL
                let finalURLString: String
                if urlString == "app-settings:" || urlString.hasPrefix("app-settings:") {
                    #if canImport(UIKit) && !os(macOS)
                    finalURLString = UIApplication.openSettingsURLString
                    #else
                    finalURLString = "x-apple.systempreferences:"
                    #endif
                } else {
                    finalURLString = urlString
                }

                guard let url = URL(string: finalURLString) else {
                    throw URLOpenerError.invalidURL(urlString)
                }

                let success = await openURL(url)
                if success {
                    return "Opened: \(urlString)"
                } else {
                    throw URLOpenerError.cannotOpen(urlString)
                }
            }
        )
    }

    @MainActor
    private static func openURL(_ url: URL) async -> Bool {
        #if canImport(UIKit) && !os(macOS)
        return await UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }
}

private enum URLOpenerError: Error, LocalizedError {
    case missingURL
    case invalidURL(String)
    case cannotOpen(String)

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Missing 'url' parameter"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .cannotOpen(let url):
            return "Cannot open URL: \(url)"
        }
    }
}
