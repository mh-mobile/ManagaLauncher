// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OGPKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "OGPKit", targets: ["OGPKit"]),
    ],
    dependencies: [
        .package(path: "../PlatformKit"),
    ],
    targets: [
        .target(name: "OGPKit", dependencies: ["PlatformKit"]),
    ]
)
