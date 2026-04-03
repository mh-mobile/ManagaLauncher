import SwiftUI

struct DayPageView: View {
    let day: DayOfWeek
    var viewModel: MangaViewModel
    let displayMode: DisplayMode
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    let headerHeight: CGFloat
    @Binding var selectedPublisher: String?
    @Binding var showingAddSheet: Bool
    @Binding var isGridEditMode: Bool
    @Binding var editingEntry: MangaEntry?
    @Binding var draggingEntryID: UUID?
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    let onOpenURL: (String) -> Void

    var body: some View {
        let _ = viewModel.refreshCounter
        let allEntries = viewModel.fetchEntries(for: day)
        let entries = if let selectedPublisher {
            allEntries.filter { $0.publisher == selectedPublisher }
        } else {
            allEntries
        }

        if displayMode == .list && !allEntries.isEmpty && !entries.isEmpty {
            MangaListView(entries: entries, day: day, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, headerHeight: headerHeight, editingEntry: $editingEntry, listEditMode: $listEditMode, onOpenURL: onOpenURL)
        } else {
            GeometryReader { geo in
                ScrollView {
                    if allEntries.isEmpty {
                        EmptyStateView(hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, headerHeight: headerHeight) {
                            if day.isCompleted {
                                ContentUnavailableView {
                                    Label("完結したマンガはありません", systemImage: "checkmark.seal")
                                } description: {
                                    Text("コンテキストメニューや編集画面から\n「完結にする」でここに移動できます")
                                }
                            } else if day.isHiatus {
                                ContentUnavailableView {
                                    Label("休載中のマンガはありません", systemImage: "moon.zzz")
                                } description: {
                                    Text("コンテキストメニューや編集画面から\n「休載中にする」でここに移動できます")
                                }
                            } else {
                                ContentUnavailableView {
                                    Label("エントリなし", systemImage: "book.closed")
                                } description: {
                                    Text("\(day.displayName)に登録されたマンガはありません")
                                } actions: {
                                    Button("追加する") {
                                        showingAddSheet = true
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height - headerHeight)
                    } else if entries.isEmpty {
                        EmptyStateView(hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, headerHeight: headerHeight) {
                            ContentUnavailableView {
                                Label("該当なし", systemImage: "line.3.horizontal.decrease.circle")
                            } description: {
                                Text("この掲載誌のマンガはありません")
                            } actions: {
                                Button("フィルター解除") {
                                    selectedPublisher = nil
                                }
                            }
                        }
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height - headerHeight)
                    } else {
                        MasonryLayout(entries: entries, availableWidth: geo.size.width - 32) { entry in
                            MangaGridCell(entry: entry, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, isGridEditMode: $isGridEditMode, editingEntry: $editingEntry, onOpenURL: onOpenURL)
                                .overlay(alignment: .topLeading) {
                                    if isGridEditMode {
                                        Button {
                                            viewModel.queueDelete(entry)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .gray)
                                                .frame(width: 36, height: 36)
                                                .contentShape(Rectangle())
                                        }
                                        .offset(x: -6, y: -6)
                                    }
                                }
                                .modifier(WiggleModifier(isActive: isGridEditMode))
                                .onDrag {
                                    draggingEntryID = entry.id
                                    return NSItemProvider(object: entry.id.uuidString as NSString)
                                } preview: {
                                    MangaGridCell(entry: entry, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, isGridEditMode: $isGridEditMode, editingEntry: $editingEntry, onOpenURL: onOpenURL)
                                        .frame(width: 120)
                                }
                                .onDrop(of: [.text], delegate: GridDropDelegate(
                                    entry: entry,
                                    entries: entries,
                                    day: day,
                                    draggingEntryID: $draggingEntryID,
                                    viewModel: viewModel
                                ))
                        }
                        .padding()
                    }
                }
                .contentMargins(.top, headerHeight, for: .scrollContent)
                .scrollContentBackground(.hidden)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isGridEditMode = true
                            }
                        }
                )
                .onDrop(of: [.text], delegate: EmptyPageDropDelegate(
                    day: day,
                    draggingEntryID: $draggingEntryID,
                    viewModel: viewModel
                ))
            }
        }
    }
}
