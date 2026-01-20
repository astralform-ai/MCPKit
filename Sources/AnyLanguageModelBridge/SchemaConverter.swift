//
//  SchemaConverter.swift
//  MCPKit
//
//  Copyright (c) 2025 MCPKit. All rights reserved.
//

import AnyLanguageModel
import MCP

// MARK: - SchemaConverter

/// Converts MCP JSON Schema (`MCP.Value`) to AnyLanguageModel's `GenerationSchema`.
///
/// This converter handles the transformation between MCP's dynamic JSON Schema format
/// and AnyLanguageModel's typed schema system, enabling MCPTool to work with
/// `LanguageModelSession`.
///
/// - Note: This type is internal to the bridge module. Users should not need to
///   interact with it directly.
enum SchemaConverter {

    // MARK: - Constants

    private static let defaultSchemaName = "Arguments"

    // MARK: - Public API

    /// Converts an MCP JSON Schema to a GenerationSchema.
    ///
    /// - Parameter mcpSchema: An `MCP.Value` representing a JSON Schema object.
    /// - Returns: A `GenerationSchema` compatible with AnyLanguageModel's Tool protocol.
    ///
    /// - Note: If conversion fails, returns an empty object schema as fallback.
    static func convert(_ mcpSchema: MCP.Value) -> GenerationSchema {
        let dynamicSchema = makeDynamicSchema(from: mcpSchema, name: defaultSchemaName)

        do {
            return try GenerationSchema(root: dynamicSchema, dependencies: [])
        } catch {
            // Fallback to empty object schema if conversion fails
            // This ensures tools remain functional even with invalid schemas
            return makeEmptySchema()
        }
    }

    // MARK: - Private Helpers

    /// Pre-computed empty schema to avoid force unwraps at runtime.
    /// This is safe because an empty object schema construction cannot fail.
    private static let emptySchema: GenerationSchema = {
        let emptyRoot = DynamicGenerationSchema(
            name: defaultSchemaName,
            description: nil,
            properties: []
        )
        // swiftlint:disable:next force_try
        return try! GenerationSchema(root: emptyRoot, dependencies: [])
    }()

    private static func makeEmptySchema() -> GenerationSchema {
        emptySchema
    }

    /// Recursively converts MCP.Value to DynamicGenerationSchema.
    private static func makeDynamicSchema(
        from value: MCP.Value,
        name: String
    ) -> DynamicGenerationSchema {
        guard case .object(let dict) = value else {
            return makeScalarSchema(from: value)
        }

        let typeValue = dict["type"]
        let description = dict["description"]?.stringValue

        switch typeValue {
        case .string("object"):
            return makeObjectSchema(from: dict, name: name, description: description)

        case .string("array"):
            return makeArraySchema(from: dict, name: name, description: description)

        case .string("string"):
            if let enumValues = dict["enum"] {
                return makeEnumSchema(from: enumValues, name: name, description: description)
            }
            return DynamicGenerationSchema(type: String.self)

        case .string("integer"):
            return DynamicGenerationSchema(type: Int.self)

        case .string("number"):
            return DynamicGenerationSchema(type: Double.self)

        case .string("boolean"):
            return DynamicGenerationSchema(type: Bool.self)

        case .string("null"):
            return DynamicGenerationSchema(type: String.self)

        default:
            // Infer object type if properties exist
            if dict["properties"] != nil {
                return makeObjectSchema(from: dict, name: name, description: description)
            }
            return DynamicGenerationSchema(type: String.self)
        }
    }

    private static func makeObjectSchema(
        from dict: [String: MCP.Value],
        name: String,
        description: String?
    ) -> DynamicGenerationSchema {
        // Extract required fields
        let requiredFields: Set<String> = {
            guard case .array(let required) = dict["required"] else { return [] }
            return Set(required.compactMap { $0.stringValue })
        }()

        // Convert properties
        var properties: [DynamicGenerationSchema.Property] = []

        if case .object(let props) = dict["properties"] {
            for (propName, propSchema) in props {
                let propertySchema = makeDynamicSchema(from: propSchema, name: propName)
                let propertyDescription = extractDescription(from: propSchema)

                properties.append(DynamicGenerationSchema.Property(
                    name: propName,
                    description: propertyDescription,
                    schema: propertySchema,
                    isOptional: !requiredFields.contains(propName)
                ))
            }
        }

        return DynamicGenerationSchema(
            name: name,
            description: description,
            properties: properties
        )
    }

    private static func makeArraySchema(
        from dict: [String: MCP.Value],
        name: String,
        description: String?
    ) -> DynamicGenerationSchema {
        let itemSchema: DynamicGenerationSchema = {
            if let items = dict["items"] {
                return makeDynamicSchema(from: items, name: "\(name)Item")
            }
            return DynamicGenerationSchema(type: String.self)
        }()

        return DynamicGenerationSchema(
            arrayOf: itemSchema,
            minimumElements: dict["minItems"]?.intValue,
            maximumElements: dict["maxItems"]?.intValue
        )
    }

    private static func makeEnumSchema(
        from enumValues: MCP.Value,
        name: String,
        description: String?
    ) -> DynamicGenerationSchema {
        guard case .array(let values) = enumValues else {
            return DynamicGenerationSchema(type: String.self)
        }

        let choices = values.compactMap { $0.stringValue }
        guard !choices.isEmpty else {
            return DynamicGenerationSchema(type: String.self)
        }

        return DynamicGenerationSchema(
            name: name,
            description: description,
            anyOf: choices
        )
    }

    private static func makeScalarSchema(from value: MCP.Value) -> DynamicGenerationSchema {
        switch value {
        case .string:
            return DynamicGenerationSchema(type: String.self)
        case .int, .double:
            return DynamicGenerationSchema(type: Double.self)
        case .bool:
            return DynamicGenerationSchema(type: Bool.self)
        case .null, .data:
            return DynamicGenerationSchema(type: String.self)
        case .array:
            return DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(type: String.self))
        case .object:
            return DynamicGenerationSchema(name: "Object", description: nil, properties: [])
        }
    }

    private static func extractDescription(from value: MCP.Value) -> String? {
        guard case .object(let dict) = value else { return nil }
        return dict["description"]?.stringValue
    }
}
