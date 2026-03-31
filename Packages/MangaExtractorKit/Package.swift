// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MangaExtractorKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "MangaExtractorKit", targets: ["MangaExtractorKit"]),
    ],
    targets: [
        .target(name: "MangaExtractorKit"),
    ]
)
