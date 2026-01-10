// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MCPKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Core MCP functionality - tool registration, server hosting, client connections
        .library(
            name: "Core",
            targets: ["Core"]
        ),
        // Predefined tools - clipboard, notifications, URL opener, calendar
        .library(
            name: "Tools",
            targets: ["Tools"]
        ),
        // Full bundle - both Core and Tools
        .library(
            name: "MCPKit",
            targets: ["Core", "Tools"]
        ),
        // AnyLanguageModel bridge - MCPTool conforms to AnyLanguageModel.Tool
        // Only import this if you use AnyLanguageModel in your project
        .library(
            name: "MCPKitAnyLanguageModel",
            targets: ["MCPKitAnyLanguageModel"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        // Only fetched when MCPKitAnyLanguageModel is used
        .package(url: "https://github.com/mattt/AnyLanguageModel", from: "0.5.0"),
    ],
    targets: [
        // Core MCP functionality
        .target(
            name: "Core",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/Core"
        ),
        // Predefined tools
        .target(
            name: "Tools",
            dependencies: ["Core"],
            path: "Sources/Tools"
        ),
        // AnyLanguageModel bridge - adds Tool conformance to MCPTool
        // AnyLanguageModel is only fetched when this target is used
        .target(
            name: "MCPKitAnyLanguageModel",
            dependencies: [
                "Core",
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel")
            ],
            path: "Sources/AnyLanguageModelBridge"
        ),
    ]
)
