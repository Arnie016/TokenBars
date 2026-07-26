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
    dependencies: [
        .package(url: "https://github.com/Cindori/FluidGradient", from: "1.0.0"),
        .package(url: "https://github.com/EmergeTools/Pow", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TokenBarMac",
            dependencies: [
                .product(name: "FluidGradient", package: "FluidGradient"),
                .product(name: "Pow", package: "Pow")
            ]
        ),
        .testTarget(name: "TokenBarMacTests", dependencies: ["TokenBarMac"])
    ]
)
