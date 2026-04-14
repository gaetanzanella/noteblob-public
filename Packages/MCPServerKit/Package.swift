// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MCPServerKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "MCPServerKit", targets: ["MCPServerKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0")
    ],
    targets: [
        .target(
            name: "MCPServerKit",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ]
        ),
        .testTarget(
            name: "MCPServerKitTests",
            dependencies: [
                "MCPServerKit",
                .product(name: "MCP", package: "swift-sdk")
            ]
        )
    ]
)
