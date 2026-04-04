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
    var onSettings: () -> Void

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
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(InkTheme.onPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(InkTheme.primary.opacity(edit.isEditing ? 0.3 : 1), in: Capsule())
                    }
                }
            }
            .disabled(unreadCount == 0 || edit.isEditing || paging.currentDay.isHiatus || paging.currentDay.isCompleted)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                onToggleDisplayMode()
            } label: {
                Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
            }
            .disabled(showingWallpaperPicker)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus")
            }
            .disabled(edit.isEditing || paging.currentDay.isHiatus || paging.currentDay.isCompleted)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                onSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .disabled(edit.isEditing)
        }
    }
}
