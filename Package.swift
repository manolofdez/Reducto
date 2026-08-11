// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Reducto",
    platforms: [
        .iOS("26.0"),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Reducto",
            targets: ["Reducto"]),
    ],
    targets: [
        .target(
            name: "Reducto",
            dependencies: [],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "ReductoTests",
            dependencies: ["Reducto"]
        ),
    ]
)
