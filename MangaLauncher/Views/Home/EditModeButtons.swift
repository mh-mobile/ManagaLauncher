import SwiftUI

struct EditModeButtons: View {
    @Binding var isGridEditMode: Bool
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    @Binding var showingWallpaperPicker: Bool

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showingWallpaperPicker = true
            } label: {
                switch ThemeManager.shared.mode {
                case .classic:
                    Label("壁紙", systemImage: "photo.artframe")
                        .font(theme.headlineFont)
                        .fixedSize()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .foregroundStyle(theme.onSurface)
                        .background(.regularMaterial, in: Capsule())
                case .ink:
                    Label("壁紙", systemImage: "photo.artframe")
                        .font(theme.headlineFont)
                        .fixedSize()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .foregroundStyle(theme.onSurface)
                        .background(theme.surfaceContainerHighest, in: Capsule())
                case .retro:
                    Label("壁紙", systemImage: "photo.artframe")
                        .font(theme.headlineFont)
                        .fixedSize()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .foregroundStyle(theme.onSurface)
                        .background(theme.surfaceContainerHigh, in: Capsule())
                }
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGridEditMode = false
                    #if os(iOS) || os(visionOS)
                    listEditMode = .inactive
                    #endif
                }
            } label: {
                switch ThemeManager.shared.mode {
                case .classic:
                    Text("完了")
                        .font(theme.headlineFont)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .foregroundStyle(theme.onSurface)
                        .background(.regularMaterial, in: Capsule())
                case .ink:
                    Text("完了")
                        .font(theme.headlineFont)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .foregroundStyle(theme.onPrimary)
                        .background(theme.primary, in: Capsule())
                case .retro:
                    Text("完了")
                        .font(theme.headlineFont)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .foregroundStyle(theme.onPrimary)
                        .background(
                            LinearGradient(colors: [theme.primaryDim, theme.primary], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
            }
        }
        .shadow(color: theme.hasShadows ? .black.opacity(0.15) : .clear, radius: theme.hasShadows ? 8 : 0, y: theme.hasShadows ? 4 : 0)
        .padding(.bottom, 16)
    }
}
