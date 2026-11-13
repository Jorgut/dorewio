// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "dorewio",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VibratoCore", targets: ["VibratoCore"])
    ],
    targets: [
        .target(name: "VibratoCore"),
        .testTarget(name: "dorewioTests", dependencies: ["VibratoCore"], path: "Tests/dorewioTests")
    ]
)
