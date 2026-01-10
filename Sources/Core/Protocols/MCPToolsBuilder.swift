//
//  MCPToolsBuilder.swift
//  MCPKit
//
//  Result builder for composing MCP tools with SwiftUI-like syntax.
//

import Foundation

/// A result builder for composing arrays of MCP tools.
///
/// `MCPToolsBuilder` provides a clean, declarative syntax for combining tools
/// from multiple sources, similar to SwiftUI's view builders.
///
/// ## Usage
///
/// ### Basic composition
/// ```swift
/// @MCPToolsBuilder
/// var myTools: [MCPTool] {
///     DeviceInfoTool.tools
///     ClipboardTool.tools
///     LocationTool.tools
/// }
/// ```
///
/// ### With conditionals
/// ```swift
/// @MCPToolsBuilder
/// var myTools: [MCPTool] {
///     DeviceInfoTool.tools
///     #if os(iOS)
///     HapticsTool.tools
///     #endif
///     if showAdvanced {
///         AdvancedTool.tools
///     }
/// }
/// ```
///
/// ### Single tool
/// ```swift
/// @MCPToolsBuilder
/// var myTools: [MCPTool] {
///     DeviceInfoTool.tools
///     MCPTool(name: "custom", description: "My custom tool") { _ in
///         return "Hello"
///     }
/// }
/// ```
@resultBuilder
public struct MCPToolsBuilder {
    /// Build a block from multiple tool arrays.
    public static func buildBlock(_ components: [MCPTool]...) -> [MCPTool] {
        components.flatMap { $0 }
    }

    /// Build from a single expression (tool array).
    public static func buildExpression(_ expression: [MCPTool]) -> [MCPTool] {
        expression
    }

    /// Build from a single tool.
    public static func buildExpression(_ expression: MCPTool) -> [MCPTool] {
        [expression]
    }

    /// Handle optional content (if without else).
    public static func buildOptional(_ component: [MCPTool]?) -> [MCPTool] {
        component ?? []
    }

    /// Handle if-else (first branch).
    public static func buildEither(first component: [MCPTool]) -> [MCPTool] {
        component
    }

    /// Handle if-else (second branch).
    public static func buildEither(second component: [MCPTool]) -> [MCPTool] {
        component
    }

    /// Handle for-in loops.
    public static func buildArray(_ components: [[MCPTool]]) -> [MCPTool] {
        components.flatMap { $0 }
    }

    /// Handle #available checks.
    public static func buildLimitedAvailability(_ component: [MCPTool]) -> [MCPTool] {
        component
    }
}
