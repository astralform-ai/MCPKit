//
//  MCPTool+Tool.swift
//  MCPKit
//
//  Copyright (c) 2025 MCPKit. All rights reserved.
//

import AnyLanguageModel
import Core
import Foundation
import MCP

// MARK: - MCPTool + AnyLanguageModel.Tool

/// Extends `MCPTool` to conform to AnyLanguageModel's `Tool` protocol.
///
/// This conformance enables MCPTool instances to be used directly with
/// `LanguageModelSession`, allowing seamless integration between MCP tools
/// and LLM function calling.
///
/// ## Usage
///
/// ```swift
/// import MCPKit
/// import MCPKitAnyLanguageModel
/// import AnyLanguageModel
///
/// // Create an MCPTool
/// let weatherTool = MCPTool(
///     name: "get_weather",
///     description: "Get current weather for a city",
///     inputSchema: .object([
///         "type": .string("object"),
///         "properties": .object([
///             "city": .object(["type": .string("string")])
///         ]),
///         "required": .array([.string("city")])
///     ])
/// ) { args in
///     let city = args?["city"]?.stringValue ?? "Unknown"
///     return "Weather in \(city): Sunny, 72F"
/// }
///
/// // Use with LanguageModelSession - no conversion needed
/// let session = LanguageModelSession(
///     model: AnthropicLanguageModel(apiKey: key),
///     tools: [weatherTool]
/// )
///
/// let response = try await session.respond {
///     Prompt("What's the weather in Tokyo?")
/// }
/// ```
extension MCPTool: AnyLanguageModel.Tool {

    public typealias Arguments = GeneratedContent
    public typealias Output = String

    /// The JSON Schema for this tool's parameters, converted to GenerationSchema format.
    public var parameters: GenerationSchema {
        SchemaConverter.convert(inputSchema)
    }

    /// Executes the tool with arguments provided by the language model.
    ///
    /// - Parameter arguments: The `GeneratedContent` containing tool arguments from the LLM.
    /// - Returns: The tool's text output.
    /// - Throws: `MCPToolError.executionFailed` if the tool returns an error result.
    public func call(arguments: GeneratedContent) async throws -> String {
        // Convert LLM arguments to MCP format
        let mcpArguments = ValueConverter.extractArguments(from: arguments)

        // Execute the tool
        let result = await execute(arguments: mcpArguments)

        // Convert result content to string
        let output = formatResultContent(result.content)

        // Check for error
        if result.isError == true {
            throw MCPToolError.executionFailed(output)
        }

        return output
    }

    // MARK: - Private Helpers

    private func formatResultContent(_ content: [MCP.Tool.Content]) -> String {
        content.map { item -> String in
            switch item {
            case .text(let text):
                return text
            case .image(data: let data, mimeType: let mimeType, metadata: _):
                return "[Image: \(mimeType), \(data.count) characters]"
            case .resource(uri: let uri, mimeType: _, text: _):
                return "[Resource: \(uri)]"
            case .audio(data: let data, mimeType: let mimeType):
                return "[Audio: \(mimeType), \(data.count) characters]"
            }
        }.joined(separator: "\n")
    }
}

// MARK: - MCPToolError

/// Errors that can occur when executing an MCPTool via AnyLanguageModel.
public enum MCPToolError: Error, LocalizedError, Sendable {

    /// The tool execution returned an error result.
    ///
    /// - Parameter message: The error message from the tool.
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return message
        }
    }
}
