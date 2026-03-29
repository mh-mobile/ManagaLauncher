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
    private static let originalImageFileName = "wallpaper_original.jpg"

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

    static var cropScale: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "wallpaperCropScale").nonZeroOrDefault(1.0)) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "wallpaperCropScale") }
    }

    static var cropOffsetX: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "wallpaperCropOffsetX")) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "wallpaperCropOffsetX") }
    }

    static var cropOffsetY: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "wallpaperCropOffsetY")) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "wallpaperCropOffsetY") }
    }

    static func saveImage(_ data: Data) {
        guard let url = imageURL else { return }
        try? data.write(to: url)
    }

    static func loadImage() -> Data? {
        guard let url = imageURL else { return nil }
        return try? Data(contentsOf: url)
    }

    static func saveOriginalImage(_ data: Data) {
        guard let url = originalImageURL else { return }
        try? data.write(to: url)
    }

    static func loadOriginalImage() -> Data? {
        guard let url = originalImageURL else { return nil }
        return try? Data(contentsOf: url)
    }

    static func removeImage() {
        if let url = imageURL { try? FileManager.default.removeItem(at: url) }
        if let url = originalImageURL { try? FileManager.default.removeItem(at: url) }
    }

    private static var imageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(imageFileName)
    }

    private static var originalImageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(originalImageFileName)
    }
}

private extension Double {
    func nonZeroOrDefault(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}

struct WallpaperPreviewSnapshot {
    var wallpaperType: WallpaperType = .none
    var colorName: String = "blue"
    var customColorHex: String = "007AFF"
    var imageData: Data?
    var pendingOriginalData: Data?

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
        if let data = pendingOriginalData {
            WallpaperManager.saveOriginalImage(data)
        }
    }
}
