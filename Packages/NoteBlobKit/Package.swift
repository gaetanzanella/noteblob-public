// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NoteBlobKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "NoteBlobKit", targets: ["NoteBlobKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/ibrahimcetin/SwiftGitX.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "NoteBlobKit",
            dependencies: [
                .product(name: "SwiftGitX", package: "SwiftGitX")
            ]
        ),
        .testTarget(
            name: "NoteBlobKitTests",
            dependencies: ["NoteBlobKit"]
        )
    ]
)
