// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenBarMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokenBarMac", targets: ["TokenBarMac"])
    ],
    targets: [
        .executableTarget(name: "TokenBarMac")
    ]
)
