// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TreeDistance",
    products: [
        .library(
            name: "TreeDistance",
            targets: ["TreeDistance"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wolfmcnally/WolfBase.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/wolfmcnally/swift-collections", .upToNextMajor(from: "1.1.0")),
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
