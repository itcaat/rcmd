// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "rcmd",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "rcmd-app", targets: ["RcmdApp"])
    ],
    targets: [
        .executableTarget(
            name: "RcmdApp",
            path: "Sources/RcmdApp",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "RcmdAppTests",
            dependencies: ["RcmdApp"],
            path: "Tests/RcmdAppTests"
        )
    ]
)
