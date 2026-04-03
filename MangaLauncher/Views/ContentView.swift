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
                                PublisherFilterView(publishers: publishers, selectedPublisher: $selectedPublisher)
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
                    ContentToolbar(
                        viewModel: viewModel,
                        displayMode: displayMode,
                        pageIndex: pageIndex,
                        isGridEditMode: isGridEditMode,
                        showingWallpaperPicker: showingWallpaperPicker,
                        listEditMode: listEditMode,
                        selectedPublisher: selectedPublisher,
                        dayForPageIndex: dayForPageIndex,
                        onCatchUp: { showingCatchUp = true },
                        onToggleDisplayMode: {
                            withAnimation {
                                isGridEditMode = false
                                listEditMode = .inactive
                                displayMode = displayMode == .list ? .grid : .list
                            }
                        },
                        onAdd: { showingAddSheet = true },
                        onSettings: { showingSettings = true }
                    )
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

    private func dayPage(day: DayOfWeek, viewModel: MangaViewModel) -> some View {
        DayPageView(day: day, viewModel: viewModel, displayMode: displayMode, hasWallpaper: hasWallpaper, reduceTransparency: reduceTransparency, headerHeight: headerHeight, selectedPublisher: $selectedPublisher, showingAddSheet: $showingAddSheet, isGridEditMode: $isGridEditMode, editingEntry: $editingEntry, draggingEntryID: $draggingEntryID, listEditMode: $listEditMode, onOpenURL: openMangaURL)
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
