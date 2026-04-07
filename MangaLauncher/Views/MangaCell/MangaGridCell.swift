import SwiftUI
import PlatformKit

struct MangaGridCell: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    @Binding var isGridEditMode: Bool
    @Binding var editingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        if entry.isDeleted || entry.modelContext == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.fromName(entry.iconColor))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay {
                            Text(entry.name)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(8)
                        }
                }

                HStack(alignment: .top, spacing: 4) {
                    if !entry.isRead {
                        Circle()
                            .fill(theme.usesCustomSurface ? theme.badgeColor : Color.accentColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 4)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(theme.captionFont)
                            .foregroundStyle(theme.usesCustomSurface ? theme.onSurface : .primary)
                            .lineLimit(2)
                        if !entry.publisher.isEmpty {
                            Text(entry.publisher)
                                .font(theme.caption2Font)
                                .foregroundStyle(theme.usesCustomSurface ? theme.onSurfaceVariant : .secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, hasWallpaper ? 8 : 0)
                .padding(.vertical, hasWallpaper ? 6 : 0)
                .background {
                    if hasWallpaper {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemFill))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.name)\(entry.publisher.isEmpty ? "" : "、\(entry.publisher)")\(entry.isRead ? "" : "、未読")")
            .accessibilityHint("タップでサイトを開く")
            .onTapGesture {
                if isGridEditMode {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGridEditMode = false
                    }
                } else {
                    onOpenURL(entry.url)
                }
            }
            .contextMenu {
                MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGridEditMode = true
                    }
                }
            }
        }
    }
}
