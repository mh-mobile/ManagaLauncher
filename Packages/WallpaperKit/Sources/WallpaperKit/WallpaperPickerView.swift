import SwiftUI
import PhotosUI

public struct WallpaperPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var preview: WallpaperPreviewSnapshot
    @Binding var previewActive: Bool

    @State private var wallpaperType: WallpaperType = .none
    @State private var selectedColor: String = "blue"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customColor: Color = .blue
    @State private var didLoad = false
    @State private var initialSnapshot = WallpaperPreviewSnapshot()

    private let presetColors: [(name: String, color: Color)] = [
        ("blue", .blue), ("purple", .purple), ("pink", .pink),
        ("red", .red), ("orange", .orange), ("yellow", .yellow),
        ("green", .green), ("teal", .teal), ("gray", .gray), ("black", .black),
    ]

    public init(preview: Binding<WallpaperPreviewSnapshot>, previewActive: Binding<Bool>) {
        self._preview = preview
        self._previewActive = previewActive
    }

    public var body: some View {
        NavigationStack {
            List {
                noneSection
                presetColorSection
                customColorSection
                photoSection
            }
            .navigationTitle("壁紙")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        preview = initialSnapshot
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        preview.commit()
                        dismiss()
                    }
                }
            }
            .task {
                initialSnapshot = .capture()
                wallpaperType = initialSnapshot.wallpaperType
                selectedColor = initialSnapshot.colorName
                customColor = Color(hex: initialSnapshot.customColorHex)
                preview.wallpaperType = initialSnapshot.wallpaperType
                preview.colorName = initialSnapshot.colorName
                preview.customColorHex = initialSnapshot.customColorHex
                preview.imageData = initialSnapshot.imageData
                preview.pendingOriginalData = WallpaperManager.loadOriginalImage()
                try? await Task.sleep(for: .milliseconds(100))
                didLoad = true
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let jpeg = downsizedJPEGData(data, maxDimension: 2400) {
                            #if canImport(UIKit)
                            try? await Task.sleep(for: .milliseconds(600))
                            presentNewPhotoCrop(originalJpeg: jpeg)
                            #else
                            preview.imageData = jpeg
                            preview.pendingOriginalData = jpeg
                            wallpaperType = .image
                            apply()
                            #endif
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var noneSection: some View {
        Section {
            Button {
                wallpaperType = .none
                apply()
            } label: {
                HStack {
                    Text("なし").foregroundStyle(.primary)
                    Spacer()
                    if wallpaperType == .none {
                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    private var presetColorSection: some View {
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
    }

    private var customColorSection: some View {
        Section("カスタムカラー") {
            HStack {
                ColorPicker("色を選択", selection: $customColor, supportsOpacity: false)
                if wallpaperType == .color && selectedColor == "custom" {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
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
                    Circle().fill(customColor).frame(width: 44, height: 44)
                    Text("この色を適用").foregroundStyle(.primary)
                    Spacer()
                    if wallpaperType == .color && selectedColor == "custom" {
                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        Section("写真") {
            if wallpaperType == .image,
               let imageData = preview.imageData,
               let image = imageData.toSwiftUIImage() {
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

            if wallpaperType == .image, preview.imageData != nil {
                #if canImport(UIKit)
                Button {
                    presentPositionAdjust()
                } label: {
                    Label("位置を調整", systemImage: "crop")
                }
                #endif

                Button(role: .destructive) {
                    wallpaperType = .none
                    preview.imageData = nil
                    preview.pendingOriginalData = nil
                    apply()
                } label: {
                    Label("壁紙を削除", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Crop

    #if canImport(UIKit)
    private func presentNewPhotoCrop(originalJpeg: Data) {
        WallpaperCropPresenter.present(
            imageData: originalJpeg,
            initialScale: 1.0,
            initialOffset: .zero
        ) { croppedData in
            preview.pendingOriginalData = originalJpeg
            preview.imageData = croppedData
            wallpaperType = .image
            apply()
        } onCancel: {
            wallpaperType = preview.wallpaperType
            selectedColor = preview.colorName
        }
    }

    private func presentPositionAdjust() {
        guard let data = preview.pendingOriginalData
                ?? WallpaperManager.loadOriginalImage()
                ?? preview.imageData else { return }

        WallpaperCropPresenter.present(
            imageData: data,
            initialScale: WallpaperManager.cropScale,
            initialOffset: CGSize(width: WallpaperManager.cropOffsetX, height: WallpaperManager.cropOffsetY)
        ) { croppedData in
            preview.imageData = croppedData
            wallpaperType = .image
            apply()
        } onCancel: {
            wallpaperType = preview.wallpaperType
            selectedColor = preview.colorName
        }
    }
    #endif

    // MARK: - Helpers

    private func apply() {
        preview.wallpaperType = wallpaperType
        preview.colorName = selectedColor
        preview.customColorHex = customColor.toHex()
        previewActive = true
    }
}
