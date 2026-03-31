// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PlatformKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PlatformKit", targets: ["PlatformKit"]),
    ],
    targets: [
        .target(name: "PlatformKit"),
    ]
)
