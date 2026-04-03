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
                    .font(.headline)
                    .fixedSize()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .foregroundStyle(.primary)
                    .background(.regularMaterial, in: Capsule())
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
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .foregroundStyle(.primary)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.bottom, 16)
    }
}
