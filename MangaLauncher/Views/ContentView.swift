import SwiftUI
import SwiftData

enum DisplayMode: String {
    case list, grid
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var viewModel: MangaViewModel?
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var showingCatchUp = false
    @State private var editingEntry: MangaEntry?
    @AppStorage("displayMode") private var displayMode: DisplayMode = .grid
    @State private var draggingEntryID: UUID?
    #if os(iOS) || os(visionOS)
    @State private var listEditMode: EditMode = .inactive
    #endif
    @State private var selectedPublisher: String?
    // 0=sat(fake), 1=sun, 2=mon, ..., 7=sat, 8=sun(fake) → 9 pages for looping
    @State private var pageIndex: Int = 0

    private func dayForPageIndex(_ index: Int) -> DayOfWeek {
        // page 0 = fake saturday, 1=sunday, 2=monday, ..., 7=saturday, 8=fake sunday
        let raw = (index - 1 + 7) % 7  // 0=sunday ... 6=saturday
        return DayOfWeek(rawValue: raw) ?? .sunday
    }

    private func pageIndexForDay(_ day: DayOfWeek) -> Int {
        return day.rawValue + 1  // sunday(0)→1, monday(1)→2, ..., saturday(6)→7
    }

    var body: some View {
        NavigationStack {
            if let viewModel {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        dayTabBar(viewModel: viewModel)
                        let publishers = viewModel.publishers(for: viewModel.selectedDay)
                        if !publishers.isEmpty {
                            publisherFilter(publishers: publishers)
                        }
                        dayPager(viewModel: viewModel)
                    }

                    if !viewModel.pendingDeleteEntries.isEmpty {
                        deleteToast(viewModel: viewModel)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.pendingDeleteEntries.isEmpty)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        let unreadCount = viewModel.unreadCount(for: viewModel.selectedDay)
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
                                        .background(.red, in: Capsule())
                                }
                            }
                        }
                        .disabled(unreadCount == 0)
                    }
                    ToolbarItem(placement: .automatic) {
                        Button {
                            withAnimation {
                                #if os(iOS) || os(visionOS)
                                listEditMode = .inactive
                                #endif
                                displayMode = displayMode == .list ? .grid : .list
                            }
                        } label: {
                            Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
                    }
                    #if os(iOS) || os(visionOS)
                    if displayMode == .list && !viewModel.fetchEntries(for: viewModel.selectedDay).isEmpty {
                        ToolbarItem(placement: .automatic) {
                            Button(listEditMode == .active ? "完了" : "編集") {
                                withAnimation {
                                    listEditMode = listEditMode == .active ? .inactive : .active
                                }
                            }
                        }
                    }
                    #endif
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
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
                    CatchUpView(viewModel: viewModel, day: viewModel.selectedDay)
                }
                .onAppear {
                    pageIndex = pageIndexForDay(viewModel.selectedDay)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = MangaViewModel(modelContext: modelContext)
            }
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

    @ViewBuilder
    private func dayTabBar(viewModel: MangaViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(DayOfWeek.allCases) { day in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedDay = day
                        pageIndex = pageIndexForDay(day)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.shortName)
                            .font(.headline)
                            .foregroundStyle(
                                viewModel.selectedDay == day
                                    ? Color.accentColor
                                    : .secondary
                            )
                        Circle()
                            .fill(day == .today
                                ? (viewModel.selectedDay == day ? Color.accentColor : .secondary)
                                : .clear
                            )
                            .frame(width: 5, height: 5)
                        Rectangle()
                            .fill(viewModel.selectedDay == day ? Color.accentColor : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .background(Color.platformBackground)
    }

    @ViewBuilder
    private func dayPager(viewModel: MangaViewModel) -> some View {
        #if os(iOS) || os(visionOS)
        // 9 pages: [sat(fake), sun, mon, tue, wed, thu, fri, sat, sun(fake)]
        TabView(selection: $pageIndex) {
            ForEach(0..<9, id: \.self) { index in
                dayPage(day: dayForPageIndex(index), viewModel: viewModel)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { oldValue, newValue in
            let day = dayForPageIndex(newValue)
            viewModel.selectedDay = day
            listEditMode = .inactive
            selectedPublisher = nil

            // Loop: if landed on fake page, jump to real page
            if newValue == 0 {
                // fake saturday → real saturday (index 7)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.none) {
                        pageIndex = 7
                    }
                }
            } else if newValue == 8 {
                // fake sunday → real sunday (index 1)
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

        if allEntries.isEmpty {
            ContentUnavailableView {
                Label("エントリなし", systemImage: "book.closed")
            } description: {
                Text("\(day.displayName)に登録された漫画はありません")
            } actions: {
                Button("追加する") {
                    showingAddSheet = true
                }
            }
        } else if entries.isEmpty {
            ContentUnavailableView {
                Label("該当なし", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("この掲載誌の漫画はありません")
            } actions: {
                Button("フィルター解除") {
                    selectedPublisher = nil
                }
            }
        } else {
            switch displayMode {
            case .list:
                listView(entries: entries, day: day, viewModel: viewModel)
            case .grid:
                gridView(entries: entries, day: day, viewModel: viewModel)
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
        .background(Color.platformBackground)
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
        }
        .listStyle(.plain)
        #if os(iOS) || os(visionOS)
        .environment(\.editMode, $listEditMode)
        #endif
    }

    @ViewBuilder
    private func gridView(entries: [MangaEntry], day: DayOfWeek, viewModel: MangaViewModel) -> some View {
        ScrollView {
            MasonryLayout(entries: entries) { entry in
                gridCell(entry: entry, viewModel: viewModel)
                    .onDrag {
                        draggingEntryID = entry.id
                        return NSItemProvider(object: entry.id.uuidString as NSString)
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

    @ViewBuilder
    private func gridCell(entry: MangaEntry, viewModel: MangaViewModel) -> some View {
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
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: entry.url) { openURL(url) }
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
            Button(role: .destructive) {
                viewModel.queueDelete(entry)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func entryRow(entry: MangaEntry) -> some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: entry.url) { openURL(url) }
        }
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
            Button(role: .destructive) {
                if let viewModel { viewModel.queueDelete(entry) }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
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
              draggingID != entry.id,
              let fromIndex = entries.firstIndex(where: { $0.id == draggingID }),
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
