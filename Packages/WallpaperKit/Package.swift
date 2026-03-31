// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WallpaperKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "WallpaperKit", targets: ["WallpaperKit"]),
    ],
    targets: [
        .target(name: "WallpaperKit"),
    ]
)
