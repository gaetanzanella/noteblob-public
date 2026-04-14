// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NoteBlobUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "NoteBlobUI", targets: ["NoteBlobUI"])
    ],
    dependencies: [
        .package(path: "../NoteBlobKit"),
        .package(path: "../TextEditorKit"),
        .package(path: "../MCPServerKit"),
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.4.0"),
        .package(url: "https://github.com/lukilabs/beautiful-mermaid-swift", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "NoteBlobUI",
            dependencies: [
                "NoteBlobKit",
                "TextEditorKit",
                "MCPServerKit",
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "BeautifulMermaid", package: "beautiful-mermaid-swift")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NoteBlobUITests",
            dependencies: ["NoteBlobUI"]
        )
    ]
)
