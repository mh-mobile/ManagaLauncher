import SwiftUI
import PhotosUI

struct WallpaperPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wallpaperType: WallpaperType = WallpaperManager.wallpaperType
    @State private var selectedColor: String = WallpaperManager.wallpaperColor
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImageData: Data? = WallpaperManager.loadImage()
    @State private var customColor: Color = Color(hex: WallpaperManager.customColorHex)

    private let presetColors: [(name: String, color: Color)] = [
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green", .green),
        ("teal", .teal),
        ("gray", .gray),
        ("black", .black),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        wallpaperType = .none
                        apply()
                    } label: {
                        HStack {
                            Text("なし")
                                .foregroundStyle(.primary)
                            Spacer()
                            if wallpaperType == .none {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                Section("プリセットカラー") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(presetColors, id: \.name) { preset in
                            Circle()
                                .fill(preset.color)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if wallpaperType == .color && selectedColor == preset.name {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    wallpaperType = .color
                                    selectedColor = preset.name
                                    apply()
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("カスタムカラー") {
                    HStack {
                        ColorPicker("色を選択", selection: $customColor, supportsOpacity: false)
                        if wallpaperType == .color && selectedColor == "custom" {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .onChange(of: customColor) { _, newColor in
                        wallpaperType = .color
                        selectedColor = "custom"
                        WallpaperManager.customColorHex = newColor.toHex()
                        apply()
                    }

                    Button {
                        wallpaperType = .color
                        selectedColor = "custom"
                        WallpaperManager.customColorHex = customColor.toHex()
                        apply()
                    } label: {
                        HStack {
                            Circle()
                                .fill(customColor)
                                .frame(width: 44, height: 44)
                            Text("この色を適用")
                                .foregroundStyle(.primary)
                            Spacer()
                            if wallpaperType == .color && selectedColor == "custom" {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                Section("写真") {
                    if let previewImageData, wallpaperType == .image,
                       let image = previewImageData.toSwiftUIImage() {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("カメラロールから選択", systemImage: "photo")
                    }

                    if wallpaperType == .image {
                        Button(role: .destructive) {
                            wallpaperType = .none
                            WallpaperManager.removeImage()
                            previewImageData = nil
                            apply()
                        } label: {
                            Label("壁紙を削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("壁紙")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let jpeg = downsizedJPEGData(data, maxDimension: 1200) {
                            previewImageData = jpeg
                            WallpaperManager.saveImage(jpeg)
                            wallpaperType = .image
                            apply()
                        }
                    }
                }
            }
        }
    }

    private func apply() {
        WallpaperManager.wallpaperType = wallpaperType
        WallpaperManager.wallpaperColor = selectedColor
    }
}

// MARK: - Color ↔ Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "007AFF"
        }
        #elseif canImport(AppKit)
        guard let converted = NSColor(self).usingColorSpace(.sRGB),
              let components = converted.cgColor.components, components.count >= 3 else {
            return "007AFF"
        }
        #endif
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
