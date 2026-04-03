import SwiftUI
import PlatformKit

struct MangaListView: View {
    let entries: [MangaEntry]
    let day: DayOfWeek
    var viewModel: MangaViewModel
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    let headerHeight: CGFloat
    @Binding var editingEntry: MangaEntry?
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    let onOpenURL: (String) -> Void

    var body: some View {
        List {
            ForEach(entries, id: \.id) { entry in
                MangaRowCell(entry: entry, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, editingEntry: $editingEntry, listEditMode: $listEditMode, onOpenURL: onOpenURL)
            }
            .onDelete { indexSet in
                let entriesToDelete = indexSet.map { entries[$0] }
                for entry in entriesToDelete {
                    viewModel.queueDelete(entry)
                }
            }
            .onMove { source, destination in
                viewModel.moveEntries(for: day, from: source, to: destination)
            }
            .listRowSeparator(hasWallpaper ? .hidden : .automatic)
        }
        .listStyle(.plain)
        .contentMargins(.top, headerHeight, for: .scrollContent)
        .scrollContentBackground(hasWallpaper ? .hidden : .automatic)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        listEditMode = .active
                    }
                }
        )
        #if os(iOS) || os(visionOS)
        .environment(\.editMode, $listEditMode)
        #endif
    }
}
