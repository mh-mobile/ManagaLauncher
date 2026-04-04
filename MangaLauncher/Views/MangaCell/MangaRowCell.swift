import SwiftUI
import PlatformKit

struct MangaRowCell: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    @Binding var editingEntry: MangaEntry?
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    let onOpenURL: (String) -> Void

    var body: some View {
        if entry.isDeleted || entry.modelContext == nil {
            EmptyView()
        } else {
            HStack(spacing: 12) {
                if !entry.isRead {
                    Text("NEW")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(InkTheme.onPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(InkTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                } else {
                    Color.clear
                        .frame(width: 28, height: 8)
                }

                EntryIcon(entry: entry, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(InkTheme.onSurface)
                    if !entry.publisher.isEmpty {
                        Text(entry.publisher)
                            .font(.system(size: 12))
                            .foregroundStyle(InkTheme.onSurfaceVariant)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(InkTheme.onSurfaceVariant.opacity(0.5))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.name)\(entry.publisher.isEmpty ? "" : "、\(entry.publisher)")\(entry.isRead ? "" : "、未読")")
            .accessibilityHint("タップでサイトを開く")
            .onTapGesture {
                onOpenURL(entry.url)
            }
            .listRowBackground(
                Group {
                    if hasWallpaper {
                        ZStack {
                            RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                                .fill(InkTheme.surfaceContainerHigh)
                            RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                                .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                    } else {
                        InkTheme.surface
                    }
                }
            )
            .contextMenu {
                MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry) {
                    #if os(iOS) || os(visionOS)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        listEditMode = .active
                    }
                    #endif
                }
            }
        }
    }
}
