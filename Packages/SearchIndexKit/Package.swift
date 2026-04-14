// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SearchIndexKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "SearchIndexKit", targets: ["SearchIndexKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "SearchIndexKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "SearchIndexKitTests",
            dependencies: ["SearchIndexKit"]
        )
    ]
)
