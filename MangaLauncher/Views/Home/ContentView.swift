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
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var viewModel: MangaViewModel
    @State private var homeState = HomeState()
    @AppStorage(UserDefaultsKeys.displayMode) private var displayMode: DisplayMode = .grid
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"
    @State private var safariURL: URL?

    @Namespace private var tabUnderline

    private let orderedDays = DayOfWeek.orderedDays

    var body: some View {
        NavigationStack {
            mainContent(viewModel: viewModel)
        }
        .onAppear {
            homeState.wallpaper.loadImage()
        }
            .onMangaDataChange {
                viewModel.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToDay)) { notification in
                if let rawValue = notification.object as? Int,
                   let day = DayOfWeek(rawValue: rawValue) {
                    viewModel.selectedDay = day
                    homeState.paging.pageIndex = homeState.paging.pageIndexForDay(day)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openCatchUp)) { _ in
                homeState.sheets.showingCatchUp = true
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(viewModel: MangaViewModel) -> some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                if ThemeManager.shared.style.usesCustomSurface && !homeState.wallpaper.effectiveHasWallpaper {
                    ThemeManager.shared.style.surface
                        .ignoresSafeArea()
                }

                WallpaperBackgroundView(
                    wallpaperRefresh: homeState.wallpaper.refresh,
                    wallpaperPreviewActive: homeState.wallpaper.previewActive,
                    wallpaperPreviewSnapshot: homeState.wallpaper.previewSnapshot,
                    cachedWallpaperImage: homeState.wallpaper.cachedWallpaperImage
                )

                DayPagerView(
                    paging: homeState.paging,
                    listEditMode: $homeState.edit.listEditMode,
                    selectedPublisher: $homeState.selectedPublisher,
                    viewModel: viewModel
                ) { day, vm in
                    DayPageView(
                        day: day,
                        viewModel: vm,
                        display: DayPageDisplayContext(
                            displayMode: displayMode,
                            hasWallpaper: homeState.wallpaper.effectiveHasWallpaper,
                            reduceTransparency: reduceTransparency,
                            headerHeight: homeState.headerHeight
                        ),
                        edit: homeState.edit,
                        selectedPublisher: $homeState.selectedPublisher,
                        showingAddSheet: $homeState.sheets.showingAddSheet,
                        commentingEntry: $homeState.commentingEntry,
                        onOpenURL: { openMangaURL($0) }
                    )
                }

                headerBar(viewModel: viewModel)
            }

            if homeState.edit.isEditing {
                EditModeButtons(
                    isGridEditMode: $homeState.edit.isGridEditMode,
                    listEditMode: $homeState.edit.listEditMode,
                    showingWallpaperPicker: $homeState.sheets.showingWallpaperPicker
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: homeState.edit.isGridEditMode)
        .animation(.easeInOut(duration: 0.2), value: homeState.edit.listEditMode)
        .toolbar {
            ContentToolbar(
                viewModel: viewModel,
                displayMode: displayMode,
                paging: homeState.paging,
                edit: homeState.edit,
                showingWallpaperPicker: homeState.sheets.showingWallpaperPicker,
                selectedPublisher: homeState.selectedPublisher,
                onCatchUp: { homeState.sheets.showingCatchUp = true },
                onToggleDisplayMode: {
                    withAnimation {
                        homeState.edit.resetEditMode()
                        displayMode = displayMode == .list ? .grid : .list
                    }
                },
                onAdd: { homeState.sheets.showingAddSheet = true }
            )
        }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .sheet(isPresented: $homeState.sheets.showingWallpaperPicker, onDismiss: {
            homeState.wallpaper.loadImage()
            homeState.wallpaper.refresh.toggle()
            homeState.wallpaper.previewActive = false
        }) {
            WallpaperPickerView(preview: $homeState.wallpaper.previewSnapshot, previewActive: $homeState.wallpaper.previewActive)
                .presentationDetents([.medium])
                .presentationBackgroundInteraction(.disabled)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $homeState.sheets.showingAddSheet) {
            EditEntryView(viewModel: viewModel, day: viewModel.selectedDay)
        }
        .sheet(item: $homeState.edit.editingEntry, onDismiss: { homeState.edit.editingEntry = nil }) { entry in
            EditEntryView(viewModel: viewModel, entry: entry)
        }
        .sheet(item: $homeState.commentingEntry, onDismiss: { homeState.commentingEntry = nil }) { entry in
            CommentListView(entry: entry, viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $homeState.sheets.showingCatchUp, onDismiss: {
            viewModel.notifyChange()
        }) {
            CatchUpView(viewModel: viewModel, day: viewModel.selectedDay, publisher: homeState.selectedPublisher)
        }
        .onAppear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                homeState.paging.pageIndex = homeState.paging.pageIndexForDay(viewModel.selectedDay)
            }
        }
        #if canImport(UIKit)
        .sheet(item: $safariURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        #endif
    }

    // MARK: - Header Bar

    private func headerBar(viewModel: MangaViewModel) -> some View {
        VStack(spacing: 0) {
            DayTabBarView(
                viewModel: viewModel,
                paging: homeState.paging,
                edit: homeState.edit,
                selectedPublisher: $homeState.selectedPublisher,
                hasWallpaper: homeState.wallpaper.effectiveHasWallpaper,
                orderedDays: orderedDays,
                tabUnderline: tabUnderline
            )
            let publishers = viewModel.publishers(for: viewModel.selectedDay)
            if !publishers.isEmpty {
                PublisherFilterView(publishers: publishers, selectedPublisher: $homeState.selectedPublisher)
            }
        }
        .background {
            #if canImport(UIKit)
            VisualEffectBlur(style: homeState.wallpaper.effectiveHasWallpaper
                ? (reduceTransparency ? .systemThinMaterial : .systemUltraThinMaterial)
                : .systemMaterial)
            .ignoresSafeArea(edges: .top)
            #else
            Rectangle().fill(homeState.wallpaper.effectiveHasWallpaper
                ? (reduceTransparency ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial))
                : AnyShapeStyle(.regularMaterial))
            .ignoresSafeArea(edges: .top)
            #endif
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
            if abs(newHeight - homeState.headerHeight) > 2 {
                homeState.headerHeight = newHeight
            }
        }
    }

    // MARK: - Helpers

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener.make(
            browserMode: browserMode,
            openURL: openURL,
            safariURL: $safariURL,
            viewModel: viewModel
        ).open(urlString)
    }
}

#Preview {
    let container = try! ModelContainer(for: MangaEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ContentView(viewModel: MangaViewModel(modelContext: container.mainContext))
        .modelContainer(container)
}
