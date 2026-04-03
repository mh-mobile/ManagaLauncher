import SwiftUI
import SwiftData
import WallpaperKit

enum DisplayMode: String {
    case list, grid
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var viewModel: MangaViewModel?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var showingCatchUp = false
    @State private var editingEntry: MangaEntry?
    @AppStorage("displayMode") private var displayMode: DisplayMode = .grid
    @AppStorage("browserMode") private var browserMode: String = "external"
    @State private var safariURL: URL?
    @State private var showingWallpaperPicker = false
    @State private var wallpaperRefresh = false
    @State private var cachedWallpaperImage: Image?
    @State private var wallpaperPreviewActive = false
    @State private var wallpaperPreviewSnapshot = WallpaperPreviewSnapshot()
    @State private var headerHeight: CGFloat = 50
    @State private var isAnimatingPageChange = false
    @State private var draggingEntryID: UUID?
    @State private var isGridEditMode = false
    #if os(iOS) || os(visionOS)
    @State private var listEditMode: EditMode = .inactive
    #endif
    @State private var selectedPublisher: String?
    // Paging: 0=hiatus(fake), 1=completed, 2=mon, 3=tue, 4=wed, 5=thu, 6=fri, 7=sat, 8=sun, 9=hiatus, 10=completed(fake) → 11 pages
    @State private var pageIndex: Int = 0

    @Namespace private var tabUnderline
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var hasWallpaper: Bool { WallpaperManager.wallpaperType != .none }
    private let orderedDays = DayOfWeek.orderedCases // [completed, mon, tue, wed, thu, fri, sat, sun, hiatus]

    private func dayForPageIndex(_ index: Int) -> DayOfWeek {
        let clamped = ((index - 1) % 9 + 9) % 9
        return orderedDays[clamped]
    }

    private func pageIndexForDay(_ day: DayOfWeek) -> Int {
        DayPagerView<EmptyView>.pageIndexForDay(day)
    }

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                hasSeenOnboarding = true
            }
        } else {
        NavigationStack {
            if let viewModel {
                ZStack(alignment: .bottom) {
                    ZStack(alignment: .top) {
                        wallpaperBackground

                        dayPager(viewModel: viewModel)

                        VStack(spacing: 0) {
                            dayTabBar(viewModel: viewModel)
                            let publishers = viewModel.publishers(for: viewModel.selectedDay)
                            if !publishers.isEmpty {
                                publisherFilter(publishers: publishers)
                            }
                        }
                        .background {
                            #if canImport(UIKit)
                            VisualEffectBlur(style: hasWallpaper
                                ? (reduceTransparency ? .systemThinMaterial : .systemUltraThinMaterial)
                                : .systemMaterial)
                            .ignoresSafeArea(edges: .top)
                            #else
                            Rectangle().fill(hasWallpaper
                                ? (reduceTransparency ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial))
                                : AnyShapeStyle(.regularMaterial))
                            .ignoresSafeArea(edges: .top)
                            #endif
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
                            if abs(newHeight - headerHeight) > 2 {
                                headerHeight = newHeight
                            }
                        }
                    }

                    if isGridEditMode || listEditMode == .active {
                        editModeButtons
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if !viewModel.pendingDeleteEntries.isEmpty {
                        DeleteToastView(viewModel: viewModel)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.pendingDeleteEntries.isEmpty)
                .animation(.easeInOut(duration: 0.2), value: isGridEditMode)
                .animation(.easeInOut(duration: 0.2), value: listEditMode)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        let allUnread = viewModel.unreadEntries(for: viewModel.selectedDay)
                        let unreadCount = if let selectedPublisher {
                            allUnread.filter { $0.publisher == selectedPublisher }.count
                        } else {
                            allUnread.count
                        }
                        let isEditMode = isGridEditMode || listEditMode == .active
                        Button {
                            showingCatchUp = true
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
                            withAnimation {
                                isGridEditMode = false
                                #if os(iOS) || os(visionOS)
                                listEditMode = .inactive
                                #endif
                                displayMode = displayMode == .list ? .grid : .list
                            }
                        } label: {
                            Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
                        .disabled(showingWallpaperPicker)
                    }
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(isGridEditMode || listEditMode == .active || dayForPageIndex(pageIndex).isHiatus || dayForPageIndex(pageIndex).isCompleted)
                    }
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .disabled(isGridEditMode || listEditMode == .active)
                    }
                }
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingWallpaperPicker, onDismiss: {
                    loadWallpaperImage()
                    wallpaperRefresh.toggle()
                    wallpaperPreviewActive = false
                }) {
                    WallpaperPickerView(preview: $wallpaperPreviewSnapshot, previewActive: $wallpaperPreviewActive)
                        .presentationDetents([.medium])
                        .presentationBackgroundInteraction(.disabled)
                        .interactiveDismissDisabled()
                }
                .sheet(isPresented: $showingAddSheet) {
                    EditEntryView(viewModel: viewModel, day: viewModel.selectedDay)
                }
                .sheet(item: $editingEntry, onDismiss: { editingEntry = nil }) { entry in
                    EditEntryView(viewModel: viewModel, entry: entry)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(viewModel: viewModel)
                }
                .fullScreenCover(isPresented: $showingCatchUp, onDismiss: {
                    viewModel.notifyChange()
                }) {
                    CatchUpView(viewModel: viewModel, day: viewModel.selectedDay, publisher: selectedPublisher)
                }
                .onAppear {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        pageIndex = pageIndexForDay(viewModel.selectedDay)
                    }
                }
                #if canImport(UIKit)
                .sheet(item: $safariURL) { url in
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
                #endif
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = MangaViewModel(modelContext: modelContext)
            }
            loadWallpaperImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mangaDataDidChange)) { _ in
            viewModel?.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToDay)) { notification in
            if let rawValue = notification.object as? Int,
               let day = DayOfWeek(rawValue: rawValue),
               let viewModel {
                viewModel.selectedDay = day
                pageIndex = pageIndexForDay(day)
            }
        }
        }
    }

    private func dayTabBar(viewModel: MangaViewModel) -> some View {
        DayTabBarView(
            viewModel: viewModel,
            pageIndex: $pageIndex,
            isAnimatingPageChange: $isAnimatingPageChange,
            selectedPublisher: $selectedPublisher,
            draggingEntryID: $draggingEntryID,
            hasWallpaper: hasWallpaper,
            orderedDays: orderedDays,
            tabUnderline: tabUnderline
        )
    }

    private func dayPager(viewModel: MangaViewModel) -> some View {
        DayPagerView(
            pageIndex: $pageIndex,
            isAnimatingPageChange: $isAnimatingPageChange,
            listEditMode: $listEditMode,
            selectedPublisher: $selectedPublisher,
            viewModel: viewModel
        ) { day, vm in
            dayPage(day: day, viewModel: vm)
        }
    }

    @ViewBuilder
    private func dayPage(day: DayOfWeek, viewModel: MangaViewModel) -> some View {
        let _ = viewModel.refreshCounter
        let allEntries = viewModel.fetchEntries(for: day)
        let entries = if let selectedPublisher {
            allEntries.filter { $0.publisher == selectedPublisher }
        } else {
            allEntries
        }

        if displayMode == .list && !allEntries.isEmpty && !entries.isEmpty {
            listView(entries: entries, day: day, viewModel: viewModel)
        } else {
            GeometryReader { geo in
                ScrollView {
                    if allEntries.isEmpty {
                        emptyStateView {
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
                        emptyStateView {
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
                            MangaGridCell(entry: entry, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, isGridEditMode: $isGridEditMode, editingEntry: $editingEntry, onOpenURL: openMangaURL)
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
                                    MangaGridCell(entry: entry, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, isGridEditMode: $isGridEditMode, editingEntry: $editingEntry, onOpenURL: openMangaURL)
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

    private func publisherFilter(publishers: [String]) -> some View {
        PublisherFilterView(publishers: publishers, selectedPublisher: $selectedPublisher)
    }

    private func listView(entries: [MangaEntry], day: DayOfWeek, viewModel: MangaViewModel) -> some View {
        MangaListView(entries: entries, day: day, viewModel: viewModel, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, headerHeight: headerHeight, editingEntry: $editingEntry, listEditMode: $listEditMode, onOpenURL: openMangaURL)
    }


    @ViewBuilder
    private func emptyStateView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if hasWallpaper {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, headerHeight)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemFill))
                        RoundedRectangle(cornerRadius: 16)
                            .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                    }
                    .padding()
                    .padding(.top, headerHeight)
                }
        } else {
            content()
                .padding(.top, headerHeight)
        }
    }

    private var editModeButtons: some View {
        EditModeButtons(isGridEditMode: $isGridEditMode, listEditMode: $listEditMode, showingWallpaperPicker: $showingWallpaperPicker)
    }



    private var wallpaperBackground: some View {
        WallpaperBackgroundView(
            wallpaperRefresh: wallpaperRefresh,
            wallpaperPreviewActive: wallpaperPreviewActive,
            wallpaperPreviewSnapshot: wallpaperPreviewSnapshot,
            cachedWallpaperImage: cachedWallpaperImage
        )
    }

    private func loadWallpaperImage() {
        if WallpaperManager.wallpaperType == .image,
           let data = WallpaperManager.loadImage(),
           let image = data.toSwiftUIImage() {
            cachedWallpaperImage = image
        } else {
            cachedWallpaperImage = nil
        }
    }

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(urlString)
    }



}

#Preview {
    ContentView()
        .modelContainer(for: MangaEntry.self, inMemory: true)
}
