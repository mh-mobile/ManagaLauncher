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
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                } else {
                    Color.clear
                        .frame(width: 8, height: 8)
                }

                EntryIcon(entry: entry, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.body)
                    if !entry.publisher.isEmpty {
                        Text(entry.publisher)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, hasWallpaper ? 4 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                onOpenURL(entry.url)
            }
            .listRowBackground(
                Group {
                    if hasWallpaper {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    } else {
                        Color.platformBackground
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
