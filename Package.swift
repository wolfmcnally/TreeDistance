// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TreeDistance",
    platforms: [.macOS(.v13), .iOS(.v15)],
    products: [
        .library(
            name: "TreeDistance",
            targets: ["TreeDistance"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wolfmcnally/WolfBase.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/apple/swift-collections", branch: "main"),
    ],
    targets: [
        .target(
            name: "TreeDistance",
            dependencies: [
                "WolfBase",
                .product(name: "Collections", package: "swift-collections"),
            ]),
        .testTarget(
            name: "TreeDistanceTests",
            dependencies: ["TreeDistance"]),
    ]
)
