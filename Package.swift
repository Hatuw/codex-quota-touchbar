// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexQuotaTouchBar",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "CodexQuotaTouchBar", targets: ["CodexQuotaTouchBar"])
    ],
    targets: [
        .executableTarget(
            name: "CodexQuotaTouchBar"
        ),
        .testTarget(
            name: "CodexQuotaTouchBarTests",
            dependencies: ["CodexQuotaTouchBar"]
        )
    ]
)
