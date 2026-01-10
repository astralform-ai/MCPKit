//
//  NotificationTool.swift
//  MCPKit
//
//  Created by MCPKit.
//

import UserNotifications
import Foundation
import Core
import MCP

/// A tool that schedules local notifications.
///
/// This tool allows AI to schedule notifications for the user.
/// Note: The app must request notification permissions.
///
/// ## Example Usage
/// ```swift
/// let local = try await manager.startLocalServer {
///     NotificationTool.tools
/// }
/// try await manager.connect(local)
/// ```
public enum NotificationTool: MCPToolProvider {
    public static var tools: [MCPTool] {
        [scheduleTool, requestPermissionTool]
    }

    /// Tool to request notification permission.
    public static var requestPermissionTool: MCPTool {
        MCPTool(
            name: "notification_request_permission",
            description: "Request permission to send notifications",
            throwingHandler: { _ in
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    return "Notification permission granted"
                } else {
                    return "Notification permission denied"
                }
            }
        )
    }

    /// Tool to schedule a local notification.
    public static var scheduleTool: MCPTool {
        MCPTool(
            name: "notification_schedule",
            description: "Schedule a local notification",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Notification title")
                    ]),
                    "body": .object([
                        "type": .string("string"),
                        "description": .string("Notification body text")
                    ]),
                    "delay": .object([
                        "type": .string("number"),
                        "description": .string("Delay in seconds before showing notification. Defaults to 5.")
                    ])
                ]),
                "required": .array([.string("title"), .string("body")])
            ]),
            throwingHandler: { args in
                guard let title = args?["title"]?.stringValue else {
                    throw NotificationError.missingTitle
                }
                guard let body = args?["body"]?.stringValue else {
                    throw NotificationError.missingBody
                }
                let delay = args?["delay"]?.doubleValue ?? 5.0

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, delay),
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )

                let center = UNUserNotificationCenter.current()
                try await center.add(request)

                return "Notification scheduled: \"\(title)\" in \(Int(delay)) seconds"
            }
        )
    }
}

private enum NotificationError: Error, LocalizedError {
    case missingTitle
    case missingBody

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Missing 'title' parameter"
        case .missingBody:
            return "Missing 'body' parameter"
        }
    }
}
