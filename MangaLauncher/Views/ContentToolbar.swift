import SwiftUI

struct ContentToolbar: ToolbarContent {
    var viewModel: MangaViewModel
    let displayMode: DisplayMode
    let pageIndex: Int
    let isGridEditMode: Bool
    let showingWallpaperPicker: Bool
    #if os(iOS) || os(visionOS)
    let listEditMode: EditMode
    #endif
    let selectedPublisher: String?
    let dayForPageIndex: (Int) -> DayOfWeek
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
            let isEditMode = isGridEditMode || listEditMode == .active
            Button {
                onCatchUp()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack")
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.red.opacity(isEditMode ? 0.3 : 1), in: Capsule())
                    }
                }
            }
            .disabled(unreadCount == 0 || isEditMode || dayForPageIndex(pageIndex).isHiatus || dayForPageIndex(pageIndex).isCompleted)
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
            .disabled(isGridEditMode || listEditMode == .active || dayForPageIndex(pageIndex).isHiatus || dayForPageIndex(pageIndex).isCompleted)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                onSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .disabled(isGridEditMode || listEditMode == .active)
        }
    }
}
