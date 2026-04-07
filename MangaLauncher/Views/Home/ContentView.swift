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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var viewModel: MangaViewModel?
    @State private var homeState = HomeState()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("displayMode") private var displayMode: DisplayMode = .grid
    @AppStorage("browserMode") private var browserMode: String = "external"

    @Namespace private var tabUnderline

    private let orderedDays = DayOfWeek.orderedCases

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                hasSeenOnboarding = true
            }
        } else {
            NavigationStack {
                if let viewModel {
                    mainContent(viewModel: viewModel)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = MangaViewModel(modelContext: modelContext)
                }
                homeState.wallpaper.loadImage()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mangaDataDidChange)) { _ in
                viewModel?.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToDay)) { notification in
                if let rawValue = notification.object as? Int,
                   let day = DayOfWeek(rawValue: rawValue),
                   let viewModel {
                    viewModel.selectedDay = day
                    homeState.paging.pageIndex = homeState.paging.pageIndexForDay(day)
                }
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(viewModel: MangaViewModel) -> some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
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
                        displayMode: displayMode,
                        hasWallpaper: homeState.wallpaper.hasWallpaper,
                        reduceTransparency: reduceTransparency,
                        headerHeight: homeState.headerHeight,
                        edit: homeState.edit,
                        selectedPublisher: $homeState.selectedPublisher,
                        showingAddSheet: $homeState.sheets.showingAddSheet,
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

            if !viewModel.pendingDeleteEntries.isEmpty {
                DeleteToastView(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.pendingDeleteEntries.isEmpty)
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
                onAdd: { homeState.sheets.showingAddSheet = true },
                onSettings: { homeState.sheets.showingSettings = true }
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
        .sheet(isPresented: $homeState.sheets.showingSettings) {
            SettingsView(viewModel: viewModel)
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
        .sheet(item: $homeState.safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
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
                hasWallpaper: homeState.wallpaper.hasWallpaper,
                orderedDays: orderedDays,
                tabUnderline: tabUnderline
            )
            let publishers = viewModel.publishers(for: viewModel.selectedDay)
            if !publishers.isEmpty {
                PublisherFilterView(publishers: publishers, selectedPublisher: $homeState.selectedPublisher)
            }
        }
        .background {
            let theme = ThemeManager.shared.style
            Group {
                if theme.usesCustomSurface && !homeState.wallpaper.hasWallpaper {
                    Rectangle().fill(theme.surface)
                } else {
                    #if canImport(UIKit)
                    VisualEffectBlur(style: homeState.wallpaper.hasWallpaper
                        ? (reduceTransparency ? .systemThinMaterial : .systemUltraThinMaterial)
                        : .systemMaterial)
                    #else
                    Rectangle().fill(homeState.wallpaper.hasWallpaper
                        ? (reduceTransparency ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial))
                        : AnyShapeStyle(.regularMaterial))
                    #endif
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
            if abs(newHeight - homeState.headerHeight) > 2 {
                homeState.headerHeight = newHeight
            }
        }
    }

    // MARK: - Helpers

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener(browserMode: browserMode, openURL: openURL) { homeState.safariURL = $0 }.open(urlString)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MangaEntry.self, inMemory: true)
}
