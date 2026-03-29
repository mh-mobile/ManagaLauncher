import SwiftUI

enum WallpaperType: String {
    case none
    case color
    case image
}

enum WallpaperManager {
    private static let typeKey = "wallpaperType"
    private static let colorKey = "wallpaperColor"
    private static let customColorKey = "wallpaperCustomColor"
    private static let imageFileName = "wallpaper.jpg"

    static var wallpaperType: WallpaperType {
        get { WallpaperType(rawValue: UserDefaults.standard.string(forKey: typeKey) ?? "none") ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: typeKey) }
    }

    static var wallpaperColor: String {
        get { UserDefaults.standard.string(forKey: colorKey) ?? "blue" }
        set { UserDefaults.standard.set(newValue, forKey: colorKey) }
    }

    static var customColorHex: String {
        get { UserDefaults.standard.string(forKey: customColorKey) ?? "007AFF" }
        set { UserDefaults.standard.set(newValue, forKey: customColorKey) }
    }

    static func saveImage(_ data: Data) {
        guard let url = imageURL else { return }
        try? data.write(to: url)
    }

    static func loadImage() -> Data? {
        guard let url = imageURL else { return nil }
        return try? Data(contentsOf: url)
    }

    static func removeImage() {
        guard let url = imageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static var imageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(imageFileName)
    }
}

struct WallpaperPreviewSnapshot {
    var wallpaperType: WallpaperType = .none
    var colorName: String = "blue"
    var customColorHex: String = "007AFF"
    var imageData: Data?

    static func capture() -> WallpaperPreviewSnapshot {
        WallpaperPreviewSnapshot(
            wallpaperType: WallpaperManager.wallpaperType,
            colorName: WallpaperManager.wallpaperColor,
            customColorHex: WallpaperManager.customColorHex,
            imageData: WallpaperManager.loadImage()
        )
    }

    func commit() {
        WallpaperManager.wallpaperType = wallpaperType
        WallpaperManager.wallpaperColor = colorName
        WallpaperManager.customColorHex = customColorHex
        if wallpaperType == .image, let data = imageData {
            WallpaperManager.saveImage(data)
        }
    }
}
