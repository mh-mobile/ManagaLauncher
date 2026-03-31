// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CloudSyncKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CloudSyncKit", targets: ["CloudSyncKit"]),
    ],
    targets: [
        .target(name: "CloudSyncKit"),
    ]
)
