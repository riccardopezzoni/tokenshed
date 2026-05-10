// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenShed",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TokenShedCore", targets: ["TokenShedCore"]),
        .executable(name: "tokenshed", targets: ["TokenShedCLI"]),
        .executable(name: "TokenShedApp", targets: ["TokenShedApp"])
    ],
    dependencies: [],
    targets: [
        .target(name: "TokenShedCore"),
        .executableTarget(
            name: "TokenShedCLI",
            dependencies: [
                "TokenShedCore"
            ]
        ),
        .executableTarget(
            name: "TokenShedApp",
            dependencies: [
                "TokenShedCore"
            ]
        ),
        .testTarget(
            name: "TokenShedCoreTests",
            dependencies: ["TokenShedCore"]
        )
    ]
)
