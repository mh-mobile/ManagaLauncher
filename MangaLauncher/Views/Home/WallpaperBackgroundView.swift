import SwiftUI
import WallpaperKit
import PlatformKit

struct WallpaperBackgroundView: View {
    let wallpaperRefresh: Bool
    let wallpaperPreviewActive: Bool
    let wallpaperPreviewSnapshot: WallpaperPreviewSnapshot
    let cachedWallpaperImage: Image?

    var body: some View {
        GeometryReader { geo in
            if wallpaperPreviewActive {
                switch wallpaperPreviewSnapshot.wallpaperType {
                case .color:
                    Self.wallpaperColor(wallpaperPreviewSnapshot.colorName, customHex: wallpaperPreviewSnapshot.customColorHex)
                        .frame(width: geo.size.width, height: geo.size.height)
                case .image:
                    if let data = wallpaperPreviewSnapshot.imageData,
                       let image = data.toSwiftUIImage() {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                case .none:
                    EmptyView()
                }
            } else {
                switch WallpaperManager.wallpaperType {
                case .color:
                    Self.wallpaperColor(WallpaperManager.wallpaperColor)
                        .frame(width: geo.size.width, height: geo.size.height)
                case .image:
                    if let image = cachedWallpaperImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                case .none:
                    EmptyView()
                }
            }
        }
        .ignoresSafeArea()
    }

    static func wallpaperColor(_ name: String, customHex: String? = nil) -> Color {
        switch name {
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "teal": .teal
        case "gray": .gray
        case "black": .black
        case "custom": Color(hex: customHex ?? WallpaperManager.customColorHex)
        default: .blue
        }
    }
}
