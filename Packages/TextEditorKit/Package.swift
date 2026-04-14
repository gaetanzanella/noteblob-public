// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TextEditorKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "TextEditorKit",
            targets: ["TextEditorKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "TextEditorKit",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "TextEditorKitTests",
            dependencies: ["TextEditorKit"]
        ),
    ]
)
