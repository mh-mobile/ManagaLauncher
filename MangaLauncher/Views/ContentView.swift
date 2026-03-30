import SwiftUI
import SwiftData

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
    // Monday-start paging: 0=sun(fake), 1=mon, 2=tue, ..., 7=sun, 8=mon(fake) → 9 pages for looping
    @State private var pageIndex: Int = 0

    @Namespace private var tabUnderline
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var hasWallpaper: Bool { WallpaperManager.wallpaperType != .none }
    private let orderedDays = DayOfWeek.orderedCases // [mon, tue, wed, thu, fri, sat, sun]

    private func dayForPageIndex(_ index: Int) -> DayOfWeek {
        // page 0 = fake sunday, 1=monday, ..., 7=sunday, 8=fake monday
        let orderedIndex = ((index - 1) % 7 + 7) % 7
        return orderedDays[orderedIndex]
    }

    private func pageIndexForDay(_ day: DayOfWeek) -> Int {
        guard let index = orderedDays.firstIndex(of: day) else { return 1 }
        return index + 1
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
                        deleteToast(viewModel: viewModel)
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
                        .disabled(unreadCount == 0 || isEditMode)
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
                        .disabled(isGridEditMode || listEditMode == .active)
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

    @State private var dropTargetDay: DayOfWeek?

    @ViewBuilder
    private func dayTabBar(viewModel: MangaViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(DayOfWeek.orderedCases) { day in
                Button {
                    isAnimatingPageChange = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        pageIndex = pageIndexForDay(day)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        viewModel.selectedDay = day
                        selectedPublisher = nil
                        isAnimatingPageChange = false
                    }
                } label: {
                    let hasUnread = viewModel.unreadCount(for: day) > 0
                    VStack(spacing: 4) {
                        Text(day.shortName)
                            .font(.headline)
                            .foregroundStyle(
                                day == .today || (hasWallpaper && viewModel.selectedDay == day)
                                    ? .white
                                    : viewModel.selectedDay == day
                                        ? Color.accentColor
                                        : .primary
                            )
                            .frame(width: 32, height: 32)
                            .background {
                                if day == .today {
                                    Circle()
                                        .fill(Color.accentColor)
                                } else if hasWallpaper && viewModel.selectedDay == day {
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                }
                            }
                        Circle()
                            .fill(hasUnread ? Color.accentColor : .clear)
                            .frame(width: 5, height: 5)
                        if dayForPageIndex(pageIndex) == day {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "tabUnderline", in: tabUnderline)
                        } else {
                            Color.clear
                                .frame(height: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dropTargetDay == day ? Color.accentColor.opacity(0.3) : .clear)
                        .padding(.horizontal, 2)
                )
                .onDrop(of: [.text], isTargeted: Binding(
                    get: { dropTargetDay == day },
                    set: { dropTargetDay = $0 ? day : nil }
                )) { providers in
                    dropTargetDay = nil
                    // Try @State first, then fall back to NSItemProvider
                    if let draggingID = draggingEntryID,
                       let entry = viewModel.findEntry(by: draggingID),
                       entry.dayOfWeek != day {
                        viewModel.moveEntryToDay(entry, to: day)
                        draggingEntryID = nil
                        withAnimation(.easeInOut(duration: 0.3)) {
                            pageIndex = pageIndexForDay(day)
                        }
                        return true
                    }
                    // Fallback: read UUID from NSItemProvider
                    guard let provider = providers.first else { return false }
                    provider.loadObject(ofClass: NSString.self) { string, _ in
                        DispatchQueue.main.async {
                            if let uuidString = string as? String,
                               let uuid = UUID(uuidString: uuidString),
                               let entry = viewModel.findEntry(by: uuid),
                               entry.dayOfWeek != day {
                                viewModel.moveEntryToDay(entry, to: day)
                                draggingEntryID = nil
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    pageIndex = pageIndexForDay(day)
                                }
                            }
                        }
                    }
                    return true
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.25), value: pageIndex)
    }

    @ViewBuilder
    private func dayPager(viewModel: MangaViewModel) -> some View {
        #if os(iOS) || os(visionOS)
        // 9 pages: [sun(fake), mon, tue, wed, thu, fri, sat, sun, mon(fake)]
        TabView(selection: $pageIndex) {
            ForEach(0..<9, id: \.self) { index in
                dayPage(day: dayForPageIndex(index), viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { oldValue, newValue in
            let day = dayForPageIndex(newValue)
            if !isAnimatingPageChange {
                // スワイプ時: UIPageViewControllerが既にアニメーション済みなので即更新
                viewModel.selectedDay = day
                listEditMode = .inactive
                selectedPublisher = nil
            }

            // Loop: if landed on fake page, jump to real page
            if newValue == 0 {
                // fake sunday → real sunday (index 7)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.none) {
                        pageIndex = 7
                    }
                }
            } else if newValue == 8 {
                // fake monday → real monday (index 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.none) {
                        pageIndex = 1
                    }
                }
            }
        }
        #else
        dayPage(day: viewModel.selectedDay, viewModel: viewModel)
        #endif
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
                            gridCell(entry: entry, viewModel: viewModel)
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
                                    gridCell(entry: entry, viewModel: viewModel)
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
                .onLongPressGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGridEditMode = true
                    }
                }
                .onDrop(of: [.text], delegate: EmptyPageDropDelegate(
                    day: day,
                    draggingEntryID: $draggingEntryID,
                    viewModel: viewModel
                ))
            }
        }
    }

    @ViewBuilder
    private func publisherFilter(publishers: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "すべて", isSelected: selectedPublisher == nil) {
                    withAnimation { selectedPublisher = nil }
                }
                ForEach(publishers, id: \.self) { pub in
                    FilterChip(label: pub, isSelected: selectedPublisher == pub) {
                        withAnimation { selectedPublisher = selectedPublisher == pub ? nil : pub }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func listView(entries: [MangaEntry], day: DayOfWeek, viewModel: MangaViewModel) -> some View {
        List {
            ForEach(entries, id: \.id) { entry in
                entryRow(entry: entry)
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

    @ViewBuilder
    private func gridView(entries: [MangaEntry], day: DayOfWeek, viewModel: MangaViewModel) -> some View {
        GeometryReader { geo in
        ScrollView {
            MasonryLayout(entries: entries, availableWidth: geo.size.width - 32) { entry in
                gridCell(entry: entry, viewModel: viewModel)
                    .overlay(alignment: .topLeading) {
                        if isGridEditMode {
                            Button {
                                viewModel.queueDelete(entry)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .gray)
                            }
                            .offset(x: -6, y: -6)
                        }
                    }
                    .modifier(WiggleModifier(isActive: isGridEditMode))
                    .onDrag {
                        draggingEntryID = entry.id
                        return NSItemProvider(object: entry.id.uuidString as NSString)
                    } preview: {
                        gridCell(entry: entry, viewModel: viewModel)
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
        .contentMargins(.top, headerHeight, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .contentShape(Rectangle())
        .onLongPressGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isGridEditMode = true
            }
        }
        .onDrop(of: [.text], delegate: EmptyPageDropDelegate(
            day: day,
            draggingEntryID: $draggingEntryID,
            viewModel: viewModel
        ))
        }
    }

    @ViewBuilder
    private func gridCell(entry: MangaEntry, viewModel: MangaViewModel) -> some View {
        if entry.isDeleted || entry.modelContext == nil {
            EmptyView()
        } else {
        VStack(alignment: .leading, spacing: 6) {
            if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorFromName(entry.iconColor))
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        Text(entry.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(8)
                    }
            }

            HStack(alignment: .top, spacing: 4) {
                if !entry.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 4)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if !entry.publisher.isEmpty {
                        Text(entry.publisher)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, hasWallpaper ? 8 : 0)
            .padding(.vertical, hasWallpaper ? 6 : 0)
            .background {
                if hasWallpaper {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isGridEditMode {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGridEditMode = false
                }
            } else {
                openMangaURL(entry.url)
            }
        }
        .contextMenu {
            Button {
                if entry.isRead {
                    viewModel.markAsUnread(entry)
                } else {
                    viewModel.markAsRead(entry)
                }
            } label: {
                Label(entry.isRead ? "未読にする" : "既読にする",
                      systemImage: entry.isRead ? "envelope.badge" : "envelope.open")
            }
            Button {
                editingEntry = entry
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGridEditMode = true
                }
            } label: {
                Label("並び替え", systemImage: "arrow.up.arrow.down")
            }
            Button(role: .destructive) {
                viewModel.queueDelete(entry)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        }
    }

    @ViewBuilder
    private func entryRow(entry: MangaEntry) -> some View {
        if entry.isDeleted || entry.modelContext == nil {
            EmptyView()
        } else {
        HStack(spacing: 12) {
            if !entry.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            } else {
                Color.clear
                    .frame(width: 8, height: 8)
            }

            entryIcon(for: entry, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                if !entry.publisher.isEmpty {
                    Text(entry.publisher)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, hasWallpaper ? 4 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            openMangaURL(entry.url)
        }
        .listRowBackground(
            Group {
                if hasWallpaper {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                } else {
                    Color.platformBackground
                }
            }
        )
        .contextMenu {
            Button {
                if let viewModel {
                    if entry.isRead {
                        viewModel.markAsUnread(entry)
                    } else {
                        viewModel.markAsRead(entry)
                    }
                }
            } label: {
                Label(entry.isRead ? "未読にする" : "既読にする",
                      systemImage: entry.isRead ? "envelope.badge" : "envelope.open")
            }
            Button {
                editingEntry = entry
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    listEditMode = .active
                }
            } label: {
                Label("並び替え", systemImage: "arrow.up.arrow.down")
            }
            Button(role: .destructive) {
                if let viewModel { viewModel.queueDelete(entry) }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        }
    }

    @ViewBuilder
    private func emptyStateView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if hasWallpaper {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, headerHeight)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                        .padding()
                        .padding(.top, headerHeight)
                }
        } else {
            content()
                .padding(.top, headerHeight)
        }
    }

    @ViewBuilder
    private var editModeButtons: some View {
        HStack(spacing: 12) {
            Button {
                showingWallpaperPicker = true
            } label: {
                Label("壁紙", systemImage: "photo.artframe")
                    .font(.headline)
                    .fixedSize()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .foregroundStyle(.primary)
                    .background(.regularMaterial, in: Capsule())
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGridEditMode = false
                    listEditMode = .inactive
                }
            } label: {
                Text("完了")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .foregroundStyle(.primary)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func entryIcon(for entry: MangaEntry, size: CGFloat) -> some View {
        if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size > 40 ? 8 : 6))
        } else {
            Circle()
                .fill(colorFromName(entry.iconColor))
                .frame(width: size, height: size)
                .overlay {
                    Text(String(entry.name.prefix(1)))
                        .font(size > 40 ? .title : .headline)
                        .foregroundStyle(.white)
                }
        }
    }

    @ViewBuilder
    private var wallpaperBackground: some View {
        let _ = wallpaperRefresh
        GeometryReader { geo in
            if wallpaperPreviewActive {
                switch wallpaperPreviewSnapshot.wallpaperType {
                case .color:
                    wallpaperColor(wallpaperPreviewSnapshot.colorName, customHex: wallpaperPreviewSnapshot.customColorHex)
                        .frame(width: geo.size.width, height: geo.size.height)
                case .image:
                    if let data = wallpaperPreviewSnapshot.imageData,
                       let image = data.toSwiftUIImage() {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                case .none:
                    EmptyView()
                }
            } else {
                switch WallpaperManager.wallpaperType {
                case .color:
                    wallpaperColor(WallpaperManager.wallpaperColor)
                        .frame(width: geo.size.width, height: geo.size.height)
                case .image:
                    if let image = cachedWallpaperImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                case .none:
                    EmptyView()
                }
            }
        }
        .ignoresSafeArea()
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

    private func wallpaperColor(_ name: String, customHex: String? = nil) -> Color {
        switch name {
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "teal": .teal
        case "gray": .gray
        case "black": .black
        case "custom": Color(hex: customHex ?? WallpaperManager.customColorHex)
        default: .blue
        }
    }

    private func openMangaURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit)
        if browserMode == "inApp" {
            safariURL = url
        } else {
            openURL(url)
        }
        #else
        openURL(url)
        #endif
    }

    @ViewBuilder
    private func deleteToast(viewModel: MangaViewModel) -> some View {
        let count = viewModel.pendingDeleteEntries.count
        HStack {
            Text("\(count)件削除しました")
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                viewModel.undoPendingDeletes()
            } label: {
                Text("元に戻す")
                    .font(.subheadline.bold())
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.darkGray))
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        default: .blue
        }
    }
}

struct WiggleModifier: ViewModifier {
    let isActive: Bool
    @State private var isWiggling = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isActive ? (isWiggling ? 2 : -2) : 0))
            .animation(
                isActive
                    ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.15),
                value: isActive ? isWiggling : false
            )
            .onChange(of: isActive) { _, active in
                isWiggling = active
            }
            .onAppear {
                isWiggling = isActive
            }
    }
}

struct GridDropDelegate: DropDelegate {
    let entry: MangaEntry
    let entries: [MangaEntry]
    let day: DayOfWeek
    @Binding var draggingEntryID: UUID?
    let viewModel: MangaViewModel

    func performDrop(info: DropInfo) -> Bool {
        draggingEntryID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingEntryID,
              draggingID != entry.id else { return }

        // Cross-day: move entry to this day first
        if !entries.contains(where: { $0.id == draggingID }),
           let draggedEntry = viewModel.findEntry(by: draggingID) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.moveEntryToDay(draggedEntry, to: day, at: entry)
            }
            return
        }

        // Same-day reorder
        guard let fromIndex = entries.firstIndex(where: { $0.id == draggingID }),
              let toIndex = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.moveEntries(
                for: day,
                from: IndexSet(integer: fromIndex),
                to: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct EmptyPageDropDelegate: DropDelegate {
    let day: DayOfWeek
    @Binding var draggingEntryID: UUID?
    let viewModel: MangaViewModel

    func performDrop(info: DropInfo) -> Bool {
        if let draggingID = draggingEntryID,
           let draggedEntry = viewModel.findEntry(by: draggingID),
           draggedEntry.dayOfWeek != day {
            viewModel.moveEntryToDay(draggedEntry, to: day)
        }
        draggingEntryID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.platformGray5)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    ContentView()
        .modelContainer(for: MangaEntry.self, inMemory: true)
}
