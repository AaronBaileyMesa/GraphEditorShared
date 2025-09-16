// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphEditorShared",
    platforms: [.watchOS(.v9)],  // Set to your project's min watchOS version
    products: [
        .library(
            name: "GraphEditorShared",
            targets: ["GraphEditorShared"])
    ],
    targets: [
        .target(
            name: "GraphEditorShared",
            path: "Sources/GraphEditorShared"  // Explicitly set path if needed
        ),
        .testTarget(
            name: "GraphEditorSharedTests",
            dependencies: ["GraphEditorShared"],
            path: "Tests/GraphEditorSharedTests"  // Explicitly set path if needed
        )
    ]
)
