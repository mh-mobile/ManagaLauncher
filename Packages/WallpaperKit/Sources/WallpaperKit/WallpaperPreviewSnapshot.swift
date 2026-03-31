import SwiftUI

public struct WallpaperPreviewSnapshot {
    public var wallpaperType: WallpaperType = .none
    public var colorName: String = "blue"
    public var customColorHex: String = "007AFF"
    public var imageData: Data?
    public var pendingOriginalData: Data?

    public init(
        wallpaperType: WallpaperType = .none,
        colorName: String = "blue",
        customColorHex: String = "007AFF",
        imageData: Data? = nil,
        pendingOriginalData: Data? = nil
    ) {
        self.wallpaperType = wallpaperType
        self.colorName = colorName
        self.customColorHex = customColorHex
        self.imageData = imageData
        self.pendingOriginalData = pendingOriginalData
    }

    public static func capture() -> WallpaperPreviewSnapshot {
        WallpaperPreviewSnapshot(
            wallpaperType: WallpaperManager.wallpaperType,
            colorName: WallpaperManager.wallpaperColor,
            customColorHex: WallpaperManager.customColorHex,
            imageData: WallpaperManager.loadImage()
        )
    }

    public func commit() {
        WallpaperManager.wallpaperType = wallpaperType
        WallpaperManager.wallpaperColor = colorName
        WallpaperManager.customColorHex = customColorHex
        if wallpaperType == .image, let data = imageData {
            WallpaperManager.saveImage(data)
        }
        if let data = pendingOriginalData {
            WallpaperManager.saveOriginalImage(data)
        }
    }
}
