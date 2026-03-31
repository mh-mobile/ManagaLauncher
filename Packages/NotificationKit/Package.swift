// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NotificationKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NotificationKit", targets: ["NotificationKit"]),
    ],
    targets: [
        .target(name: "NotificationKit"),
    ]
)
