// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GraphEditorShared",
    platforms: [
        .watchOS(.v10),   // matches your watch target (minimum deployment)
        .iOS(.v17)        // optional – nice for future iPhone companion
    ],
    products: [
        .library(
            name: "GraphEditorShared",
            targets: ["GraphEditorShared"]
        )
    ],
    targets: [
        .target(name: "GraphEditorShared"),
        .testTarget(
            name: "GraphEditorSharedTests",
            dependencies: ["GraphEditorShared"]
        )
    ]
)
