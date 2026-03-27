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
