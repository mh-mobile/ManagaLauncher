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
    @Binding var commentingEntry: MangaEntry?
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    let onOpenURL: (String) -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        List {
            ForEach(entries, id: \.id) { entry in
                MangaRowCell(entry: entry, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, editingEntry: $editingEntry, commentingEntry: $commentingEntry, listEditMode: $listEditMode, onOpenURL: onOpenURL)
            }
            .onDelete { indexSet in
                let entriesToDelete = indexSet.map { entries[$0] }
                for entry in entriesToDelete {
                    viewModel.queueDelete(entry)
                }
            }
            .if(listEditMode == .active) { view in
                view.onMove { source, destination in
                    viewModel.moveEntries(for: day, from: source, to: destination)
                }
            }
            .listRowSeparator(.hidden)
            .if(theme.usesCustomSurface) { view in
                view.listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            }

            Section {
                Color.clear
                    .frame(height: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            listEditMode = .active
                        }
                    }
            }
        }
        .listStyle(.plain)
        .contentMargins(.top, headerHeight, for: .scrollContent)
        .scrollContentBackground(theme.usesCustomSurface ? .hidden : (hasWallpaper ? .hidden : .automatic))
        .if(theme.usesCustomSurface && !hasWallpaper) { view in
            view.background(theme.surface)
        }
        #if os(iOS) || os(visionOS)
        .environment(\.editMode, $listEditMode)
        #endif
    }
}
