// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MMD",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "MMD", targets: ["MMD"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "MMD",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Sources/MMD"
        ),
        .testTarget(
            name: "MMDTests",
            dependencies: ["MMD"],
            path: "Tests/MMDTests"
        ),
    ]
)
