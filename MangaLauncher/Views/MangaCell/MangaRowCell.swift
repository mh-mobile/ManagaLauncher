import SwiftUI
import PlatformKit

struct MangaRowCell: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    let onOpenURL: (String) -> Void

    @State private var lifetimeEntry: MangaEntry?
    @AppStorage(UserDefaultsKeys.showsNextUpdateBadge) private var showsNextUpdateBadge: Bool = true

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var accessibilityLabel: String {
        entry.accessibilityDescription(nextUpdateStyle: .full, showsNextUpdateBadge: showsNextUpdateBadge)
    }

    var body: some View {
        if entry.isDeleted || entry.modelContext == nil {
            EmptyView()
        } else {
            HStack(spacing: 12) {
                switch ThemeManager.shared.mode {
                case .ink:
                    if !entry.isRead {
                        Text("NEW")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(theme.onPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    } else {
                        Color.clear
                            .frame(width: 28, height: 8)
                    }
                case .classic:
                    if !entry.isRead {
                        Circle()
                            .fill(theme.badgeColor)
                            .frame(width: 8, height: 8)
                    } else {
                        Color.clear
                            .frame(width: 8, height: 8)
                    }
                case .retro:
                    if !entry.isRead {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [theme.primaryDim, theme.primary], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 8, height: 8)
                    } else {
                        Color.clear
                            .frame(width: 8, height: 8)
                    }
                }

                EntryIcon(entry: entry, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.onSurface)
                    HStack(spacing: 4) {
                        if !entry.publisher.isEmpty {
                            Text(entry.publisher)
                                .font(theme.captionFont)
                                .foregroundStyle(theme.onSurfaceVariant)
                        }
                        if let ep = entry.currentEpisode {
                            if !entry.publisher.isEmpty {
                                Text("·")
                                    .font(theme.captionFont)
                                    .foregroundStyle(theme.onSurfaceVariant)
                            }
                            Text("既読 \(ep)話")
                                .font(theme.captionFont)
                                .foregroundStyle(theme.primary)
                        }
                    }
                }

                Spacer()

                if showsNextUpdateBadge,
                   let result = NextUpdateFormatter.format(entry.nextExpectedUpdate, style: .full) {
                    NextUpdateBadgeView(result: result)
                        .padding(.trailing, 4)
                }

                switch ThemeManager.shared.mode {
                case .ink:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.onSurfaceVariant.opacity(0.5))
                case .classic:
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                case .retro:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.onSurfaceVariant.opacity(0.4))
                }
            }
            .padding(.vertical, theme.usesCustomSurface ? 8 : (hasWallpaper ? 4 : 0))
            .padding(.horizontal, theme.usesCustomSurface ? 4 : 0)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("タップでサイトを開く")
            .onTapGesture {
                onOpenURL(entry.url)
            }
            .listRowBackground(
                Group {
                    switch ThemeManager.shared.mode {
                    case .ink:
                        if hasWallpaper {
                            ZStack {
                                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                                    .fill(Color.platformFill)
                                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                                    .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        } else {
                            theme.surface
                        }
                    case .classic:
                        if hasWallpaper {
                            ZStack {
                                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                                    .fill(Color.platformFill)
                                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                                    .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        } else {
                            Color.platformBackground
                        }
                    case .retro:
                        if hasWallpaper {
                            ZStack {
                                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                                    .fill(Color.platformFill)
                                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                                    .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        } else {
                            theme.surface
                        }
                    }
                }
            )
            .contextMenu {
                MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry, commentingEntry: $commentingEntry, onShowLifetime: { lifetimeEntry = entry }) {
                    #if os(iOS) || os(visionOS)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        listEditMode = .active
                    }
                    #endif
                }
            }
            .sheet(item: $lifetimeEntry) { entry in
                let lifetime = LifetimeBuilder.build(
                    entries: [entry],
                    activities: viewModel.allActivities(),
                    comments: viewModel.allComments()
                ).first ?? MangaLifetime(entry: entry, startDate: Date(), endDate: Date(), activityCount: 0)
                LifetimeDetailSheet(lifetime: lifetime, viewModel: viewModel)
            }
        }
    }
}
