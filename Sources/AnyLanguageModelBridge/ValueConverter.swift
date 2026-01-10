//
//  ValueConverter.swift
//  MCPKit
//
//  Copyright (c) 2025 MCPKit. All rights reserved.
//

import AnyLanguageModel
import MCP

// MARK: - ValueConverter

/// Converts between AnyLanguageModel's `GeneratedContent` and MCP's `Value` types.
///
/// This converter enables bidirectional transformation of tool arguments and results
/// between the two type systems.
///
/// - Note: This type is internal to the bridge module. Users should not need to
///   interact with it directly.
enum ValueConverter {

    // MARK: - GeneratedContent → MCP.Value

    /// Extracts tool arguments from GeneratedContent for MCPTool execution.
    ///
    /// - Parameter content: The `GeneratedContent` containing tool arguments from the LLM.
    /// - Returns: A dictionary of `MCP.Value` suitable for MCPTool, or `nil` if
    ///   the content is not a structure (object).
    static func extractArguments(from content: GeneratedContent) -> [String: MCP.Value]? {
        guard case .structure(let properties, _) = content.kind else {
            return nil
        }

        var result: [String: MCP.Value] = [:]
        for (key, value) in properties {
            result[key] = convertToMCPValue(value)
        }
        return result
    }

    /// Converts a GeneratedContent value to its MCP.Value equivalent.
    ///
    /// - Parameter content: The `GeneratedContent` to convert.
    /// - Returns: The equivalent `MCP.Value`.
    static func convertToMCPValue(_ content: GeneratedContent) -> MCP.Value {
        switch content.kind {
        case .null:
            return .null

        case .bool(let value):
            return .bool(value)

        case .number(let value):
            // Preserve integer type when possible
            if value.truncatingRemainder(dividingBy: 1) == 0,
               value >= Double(Int.min),
               value <= Double(Int.max) {
                return .int(Int(value))
            }
            return .double(value)

        case .string(let value):
            return .string(value)

        case .array(let elements):
            return .array(elements.map { convertToMCPValue($0) })

        case .structure(let properties, _):
            var dict: [String: MCP.Value] = [:]
            for (key, value) in properties {
                dict[key] = convertToMCPValue(value)
            }
            return .object(dict)
        }
    }

    // MARK: - MCP.Value → GeneratedContent

    /// Converts an MCP.Value to GeneratedContent.
    ///
    /// - Parameter value: The `MCP.Value` to convert.
    /// - Returns: The equivalent `GeneratedContent`.
    static func convertToGeneratedContent(_ value: MCP.Value) -> GeneratedContent {
        switch value {
        case .null:
            return GeneratedContent(kind: .null)

        case .bool(let b):
            return GeneratedContent(kind: .bool(b))

        case .int(let i):
            return GeneratedContent(kind: .number(Double(i)))

        case .double(let d):
            return GeneratedContent(kind: .number(d))

        case .string(let s):
            return GeneratedContent(kind: .string(s))

        case .data(_, let data):
            // Binary data is converted to base64 string representation
            return GeneratedContent(kind: .string(data.base64EncodedString()))

        case .array(let arr):
            return GeneratedContent(kind: .array(arr.map { convertToGeneratedContent($0) }))

        case .object(let dict):
            var properties: [String: GeneratedContent] = [:]
            var orderedKeys: [String] = []
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                properties[key] = convertToGeneratedContent(val)
                orderedKeys.append(key)
            }
            return GeneratedContent(kind: .structure(properties: properties, orderedKeys: orderedKeys))
        }
    }
}
