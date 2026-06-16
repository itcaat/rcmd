// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "rcmd",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "rcmd-app", targets: ["RcmdApp"])
    ],
    targets: [
        .executableTarget(
            name: "RcmdApp",
            path: "Sources/RcmdApp"
        )
    ]
)
