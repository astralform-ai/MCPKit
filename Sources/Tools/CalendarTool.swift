//
//  CalendarTool.swift
//  MCPKit
//
//  Created by MCPKit.
//

@preconcurrency import EventKit
import Foundation
import Core
import MCP

/// A tool that provides calendar operations.
///
/// This tool allows AI to read and create calendar events.
/// Note: The app must request calendar permissions.
///
/// ## Available Operations
/// - `calendar_list_events`: List upcoming events
/// - `calendar_create_event`: Create a new calendar event
///
/// ## Example Usage
/// ```swift
/// let local = try await manager.startLocalServer {
///     CalendarTool.tools
/// }
/// try await manager.connect(local)
/// ```
public enum CalendarTool: MCPToolProvider {
    public static var tools: [MCPTool] {
        [listEventsTool, createEventTool]
    }

    /// Tool to list upcoming calendar events.
    public static var listEventsTool: MCPTool {
        MCPTool(
            name: "calendar_list_events",
            description: "List upcoming calendar events. Returns events for the next 7 days by default.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "days": .object([
                        "type": .string("number"),
                        "description": .string("Number of days to look ahead. Defaults to 7.")
                    ])
                ])
            ]),
            throwingHandler: { args in
                let days = args?["days"]?.intValue ?? 7
                return try await CalendarHelper.listEvents(days: days)
            }
        )
    }

    /// Tool to create a calendar event.
    public static var createEventTool: MCPTool {
        MCPTool(
            name: "calendar_create_event",
            description: "Create a new calendar event",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Event title")
                    ]),
                    "start_date": .object([
                        "type": .string("string"),
                        "description": .string("Start date/time in ISO 8601 format (e.g., '2025-01-15T14:00:00')")
                    ]),
                    "duration_minutes": .object([
                        "type": .string("number"),
                        "description": .string("Duration in minutes. Defaults to 60.")
                    ]),
                    "notes": .object([
                        "type": .string("string"),
                        "description": .string("Optional notes for the event")
                    ])
                ]),
                "required": .array([.string("title"), .string("start_date")])
            ]),
            throwingHandler: { args in
                guard let title = args?["title"]?.stringValue else {
                    throw CalendarError.missingTitle
                }
                guard let startDateString = args?["start_date"]?.stringValue else {
                    throw CalendarError.missingStartDate
                }

                let durationMinutes = args?["duration_minutes"]?.intValue ?? 60
                let notes = args?["notes"]?.stringValue

                return try await CalendarHelper.createEvent(
                    title: title,
                    startDateString: startDateString,
                    durationMinutes: durationMinutes,
                    notes: notes
                )
            }
        )
    }
}

// MARK: - Calendar Helper

@MainActor
private final class CalendarHelper {
    private static let eventStore = EKEventStore()

    static func listEvents(days: Int) async throws -> String {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate)!

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        let events = eventStore.events(matching: predicate)

        if events.isEmpty {
            return "No events found in the next \(days) days."
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let eventList = events.prefix(20).map { event in
            let start = formatter.string(from: event.startDate)
            return "- \(event.title ?? "Untitled"): \(start)"
        }.joined(separator: "\n")

        return "Upcoming events (\(min(events.count, 20)) of \(events.count)):\n\(eventList)"
    }

    static func createEvent(
        title: String,
        startDateString: String,
        durationMinutes: Int,
        notes: String?
    ) async throws -> String {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        var startDate = formatter.date(from: startDateString)
        if startDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            startDate = formatter.date(from: startDateString)
        }
        if startDate == nil {
            // Try basic format without timezone
            let basicFormatter = DateFormatter()
            basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            startDate = basicFormatter.date(from: startDateString)
        }

        guard let start = startDate else {
            throw CalendarError.invalidDateFormat(startDateString)
        }

        let endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start)!

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = endDate
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        return "Created event: \"\(title)\" on \(displayFormatter.string(from: start))"
    }

    private static func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
}

private enum CalendarError: Error, LocalizedError {
    case accessDenied
    case missingTitle
    case missingStartDate
    case invalidDateFormat(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Please enable in Settings."
        case .missingTitle:
            return "Missing 'title' parameter"
        case .missingStartDate:
            return "Missing 'start_date' parameter"
        case .invalidDateFormat(let date):
            return "Invalid date format: \(date). Use ISO 8601 format (e.g., '2025-01-15T14:00:00')"
        }
    }
}
