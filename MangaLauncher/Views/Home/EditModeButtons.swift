import SwiftUI

struct EditModeButtons: View {
    @Binding var isGridEditMode: Bool
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    @Binding var showingWallpaperPicker: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showingWallpaperPicker = true
            } label: {
                Label("壁紙", systemImage: "photo.artframe")
                    .font(.system(size: 15, weight: .black))
                    .fixedSize()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .foregroundStyle(InkTheme.onSurface)
                    .background(InkTheme.surfaceContainerHighest, in: Capsule())
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGridEditMode = false
                    #if os(iOS) || os(visionOS)
                    listEditMode = .inactive
                    #endif
                }
            } label: {
                Text("完了")
                    .font(.system(size: 15, weight: .black))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .foregroundStyle(InkTheme.onPrimary)
                    .background(InkTheme.primary, in: Capsule())
            }
        }
        .padding(.bottom, 16)
    }
}
