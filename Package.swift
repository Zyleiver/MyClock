// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MyClock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MyClock", targets: ["MyClock"])
    ],
    targets: [
        .executableTarget(
            name: "MyClock",
            path: "Sources/MyClock"
        )
    ]
)
