// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DueBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DueBar", targets: ["DueBar"])
    ],
    targets: [
        .executableTarget(
            name: "DueBar",
            path: "Sources/DueBar",
            linkerSettings: [.linkedFramework("EventKit")]
        )
    ]
)
