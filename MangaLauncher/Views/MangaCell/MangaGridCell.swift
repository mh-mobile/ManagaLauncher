import SwiftUI
import PlatformKit

struct MangaGridCell: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    @Binding var isGridEditMode: Bool
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    @AppStorage(UserDefaultsKeys.showsNextUpdateBadge) private var showsNextUpdateBadge: Bool = true

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var accessibilityLabel: String {
        var parts = [entry.name]
        if !entry.publisher.isEmpty { parts.append(entry.publisher) }
        if !entry.isRead { parts.append("未読") }
        if showsNextUpdateBadge,
           let next = NextUpdateFormatter.format(entry.nextExpectedUpdate, style: .compact) {
            parts.append(next.accessibilityText)
        }
        return parts.joined(separator: "、")
    }

    var body: some View {
        if entry.isDeleted || entry.modelContext == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
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

                    if showsNextUpdateBadge,
                       let result = NextUpdateFormatter.format(entry.nextExpectedUpdate, style: .compact) {
                        NextUpdateBadgeView(result: result)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            // テーマに沿った塗り。`.ultraThinMaterial` だと
                            // Ink / Retro の独自背景と整合せず浮いて見える。
                            .background(
                                Capsule().fill(theme.surfaceContainerHighest.opacity(0.85))
                            )
                            .padding(4)
                    }
                }

                HStack(alignment: .top, spacing: 4) {
                    if !entry.isRead {
                        Circle()
                            .fill(theme.badgeColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 4)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.caption)
                            .foregroundStyle(theme.onSurface)
                            .lineLimit(2)
                        if !entry.publisher.isEmpty {
                            Text(entry.publisher)
                                .font(.caption2)
                                .foregroundStyle(theme.onSurfaceVariant)
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
            .accessibilityLabel(accessibilityLabel)
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
                MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry, commentingEntry: $commentingEntry) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGridEditMode = true
                    }
                }
            }
        }
    }
}
