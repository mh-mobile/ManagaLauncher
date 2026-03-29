import SwiftUI
import PhotosUI

struct WallpaperPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var preview: WallpaperPreviewSnapshot
    @Binding var previewActive: Bool
    @State private var wallpaperType: WallpaperType = .none
    @State private var selectedColor: String = "blue"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImageData: Data?
    @State private var customColor: Color = .blue
    @State private var initialSnapshot = WallpaperPreviewSnapshot()
    @State private var didLoad = false

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
                    .onChange(of: customColor) { _, _ in
                        guard didLoad, wallpaperType == .color, selectedColor == "custom" else { return }
                        apply()
                    }

                    Button {
                        wallpaperType = .color
                        selectedColor = "custom"
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
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("カメラロールから選択", systemImage: "photo")
                    }

                    if wallpaperType == .image {
                        Button(role: .destructive) {
                            wallpaperType = .none
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        preview = initialSnapshot
                        previewActive = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        preview.commit()
                        previewActive = false
                        dismiss()
                    }
                }
            }
            .task {
                initialSnapshot = .capture()
                wallpaperType = initialSnapshot.wallpaperType
                selectedColor = initialSnapshot.colorName
                customColor = Color(hex: initialSnapshot.customColorHex)
                previewImageData = initialSnapshot.imageData
                try? await Task.sleep(for: .milliseconds(100))
                didLoad = true
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let jpeg = downsizedJPEGData(data, maxDimension: 1200) {
                            #if canImport(UIKit)
                            try? await Task.sleep(for: .milliseconds(600))
                            await MainActor.run {
                            CropPresenter.present(imageData: jpeg, maxDimension: 1200, lockToScreenRatio: true) { croppedData in
                                previewImageData = croppedData
                                wallpaperType = .image
                                apply()
                            } onCancel: {
                                // do nothing
                            }
                            }
                            #else
                            previewImageData = jpeg
                            wallpaperType = .image
                            apply()
                            #endif
                        }
                    }
                }
            }
        }
    }

    private func apply() {
        preview.wallpaperType = wallpaperType
        preview.colorName = selectedColor
        preview.customColorHex = customColor.toHex()
        preview.imageData = previewImageData
        previewActive = true
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
