import SwiftUI

/// DayPageView の表示構成・装飾系の値をひとまとめにした context。
/// 親 View からの props drilling を 1 つの引数に集約するためのもの。
struct DayPageDisplayContext {
    let displayMode: DisplayMode
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    let headerHeight: CGFloat
}

struct DayPageView: View {
    let day: DayOfWeek
    var viewModel: MangaViewModel
    let display: DayPageDisplayContext
    @Bindable var edit: EditState
    @Binding var selectedPublisher: String?
    @Binding var showingAddSheet: Bool
    @Binding var commentingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        let _ = viewModel.refreshCounter
        let allEntries = viewModel.fetchEntries(for: day)
        let entries = if let selectedPublisher {
            allEntries.filter { $0.publisher == selectedPublisher }
        } else {
            allEntries
        }

        if display.displayMode == .list && !allEntries.isEmpty && !entries.isEmpty {
            MangaListView(entries: entries, day: day, viewModel: viewModel, hasWallpaper: display.hasWallpaper, reduceTransparency: display.reduceTransparency, headerHeight: display.headerHeight, editingEntry: $edit.editingEntry, commentingEntry: $commentingEntry, listEditMode: $edit.listEditMode, onOpenURL: onOpenURL)
        } else {
            GeometryReader { geo in
                ScrollView {
                    if allEntries.isEmpty {
                        EmptyStateView(hasWallpaper: display.hasWallpaper, reduceTransparency: display.reduceTransparency, headerHeight: display.headerHeight) {
                            ContentUnavailableView {
                                Label("エントリなし", systemImage: "book.closed")
                                    .modifier(ThemedLabelModifier())
                            } description: {
                                Text("\(day.displayName)に登録されたマンガはありません")
                                    .modifier(ThemedDescriptionModifier())
                            } actions: {
                                Button("追加する") {
                                    showingAddSheet = true
                                }
                                .modifier(ThemedActionModifier())
                            }
                        }
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height - display.headerHeight)
                    } else if entries.isEmpty {
                        EmptyStateView(hasWallpaper: display.hasWallpaper, reduceTransparency: display.reduceTransparency, headerHeight: display.headerHeight) {
                            ContentUnavailableView {
                                Label("該当なし", systemImage: "line.3.horizontal.decrease.circle")
                                    .modifier(ThemedLabelModifier())
                            } description: {
                                Text("この掲載誌のマンガはありません")
                                    .modifier(ThemedDescriptionModifier())
                            } actions: {
                                Button("フィルター解除") {
                                    selectedPublisher = nil
                                }
                                .modifier(ThemedActionModifier())
                            }
                        }
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height - display.headerHeight)
                    } else {
                        MasonryLayout(entries: entries, availableWidth: geo.size.width - 32) { entry in
                            MangaGridCell(entry: entry, viewModel: viewModel, hasWallpaper: display.hasWallpaper, reduceTransparency: display.reduceTransparency, isGridEditMode: $edit.isGridEditMode, editingEntry: $edit.editingEntry, commentingEntry: $commentingEntry, onOpenURL: onOpenURL)
                                .overlay(alignment: .topLeading) {
                                    if edit.isGridEditMode {
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
                                .modifier(WiggleModifier(isActive: edit.isGridEditMode))
                                .onDrag {
                                    edit.draggingEntryID = entry.id
                                    return NSItemProvider(object: entry.id.uuidString as NSString)
                                } preview: {
                                    MangaGridCell(entry: entry, viewModel: viewModel, hasWallpaper: display.hasWallpaper, reduceTransparency: display.reduceTransparency, isGridEditMode: $edit.isGridEditMode, editingEntry: $edit.editingEntry, onOpenURL: onOpenURL)
                                        .frame(width: 120)
                                }
                                .onDrop(of: [.text], delegate: GridDropDelegate(
                                    entry: entry,
                                    entries: entries,
                                    day: day,
                                    draggingEntryID: $edit.draggingEntryID,
                                    viewModel: viewModel
                                ))
                        }
                        .padding()
                    }
                }
                .contentMargins(.top, display.headerHeight, for: .scrollContent)
                .scrollContentBackground(.hidden)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                edit.isGridEditMode = true
                            }
                        }
                )
                .onDrop(of: [.text], delegate: EmptyPageDropDelegate(
                    day: day,
                    draggingEntryID: $edit.draggingEntryID,
                    viewModel: viewModel
                ))
            }
        }
    }
}

// MARK: - Themed Modifiers for DayPageView

private struct ThemedLabelModifier: ViewModifier {
    private var theme: ThemeStyle { ThemeManager.shared.style }
    func body(content: Content) -> some View {
        content.foregroundStyle(theme.onSurfaceVariant)
    }
}

private struct ThemedDescriptionModifier: ViewModifier {
    private var theme: ThemeStyle { ThemeManager.shared.style }
    func body(content: Content) -> some View {
        content.foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
    }
}

private struct ThemedActionModifier: ViewModifier {
    private var theme: ThemeStyle { ThemeManager.shared.style }
    func body(content: Content) -> some View {
        content
            .fontWeight(.bold)
            .foregroundStyle(theme.primary)
    }
}
