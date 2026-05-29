import SwiftUI

struct ContentToolbar: ToolbarContent {
    var viewModel: MangaViewModel
    let displayMode: DisplayMode
    var paging: PagingState
    var edit: EditState
    let showingWallpaperPicker: Bool
    let selectedPublisher: String?
    var onCatchUp: () -> Void
    var onToggleDisplayMode: () -> Void
    var onAdd: () -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            let allUnread = viewModel.unreadEntries(for: viewModel.selectedDay)
            let unreadCount = if let selectedPublisher {
                allUnread.filter { $0.publisher == selectedPublisher }.count
            } else {
                allUnread.count
            }
            Button {
                onCatchUp()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack")
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(theme.caption2Font.bold())
                            .foregroundStyle(theme.onPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.badgeColor.opacity(edit.isEditing ? 0.3 : 1),
                                in: Capsule())
                    }
                }
            }
            .accessibilityLabel("キャッチアップ、未読\(unreadCount)件")
            .disabled(unreadCount == 0 || edit.isEditing)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                onToggleDisplayMode()
            } label: {
                Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
            }
            .accessibilityLabel(displayMode == .list ? "グリッド表示に切り替え" : "リスト表示に切り替え")
            .disabled(showingWallpaperPicker)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("マンガを追加")
            .disabled(edit.isEditing)
        }
    }
}
