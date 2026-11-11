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
        .target(
            name: "VibratoCore",
            path: "Sources/VibratoCore"
        ),
        .testTarget(
            name: "VibratoCoreTests",
            dependencies: ["VibratoCore"],
            path: "Tests/VibratoCoreTests"
        )
    ]
)
