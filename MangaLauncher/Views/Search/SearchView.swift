import SwiftUI
import SwiftData
import PlatformKit

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var viewModel: MangaViewModel?
    @State private var searchText: String = ""
    @State private var selectedScope: SearchScope = .all
    @State private var selectedDay: DayOfWeek? = nil
    @State private var selectedColors: Set<String> = []
    @State private var safariURL: URL?
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @AppStorage("browserMode") private var browserMode: String = "external"

    private let colorLabelStore = ColorLabelStore.shared

    private var theme: ThemeStyle { ThemeManager.shared.style }

    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "すべて"
        case unread = "未読"
        case backlog = "積読"
        case serial = "連載中"
        case hiatus = "休載"
        case publicationFinished = "完結"
        case archived = "読了"
        case oneShot = "読み切り"
        case memo = "メモ"
        case comment = "コメント"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .all: "tray.full"
            case .unread: "envelope.badge"
            case .backlog: "books.vertical"
            case .serial: "book"
            case .hiatus: "moon.zzz"
            case .publicationFinished: "flag.checkered"
            case .archived: "checkmark.seal"
            case .oneShot: "doc.text"
            case .memo: "note.text"
            case .comment: "bubble.left.and.bubble.right"
            }
        }
    }

    /// 検索結果を 3 セクション（マンガ / メモ / コメント）に分類
    private struct SearchResults {
        var entries: [MangaEntry]
        var memos: [MangaEntry]
        var comments: [(comment: MangaComment, entry: MangaEntry)]

        var isEmpty: Bool { entries.isEmpty && memos.isEmpty && comments.isEmpty }
        var totalCount: Int { entries.count + memos.count + comments.count }
    }

    private var searchResults: SearchResults {
        guard let viewModel else { return SearchResults(entries: [], memos: [], comments: []) }
        let allEntries = viewModel.allEntries()
        let scoped = applyScope(to: allEntries)
        let dayFiltered = applyDayFilter(to: scoped)
        let candidates = applyColorFilter(to: dayFiltered)

        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let candidateIDs = Set(candidates.map(\.id))
        let entriesByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })

        // メモスコープ: メモを持つエントリだけをメモセクションに表示
        if selectedScope == .memo {
            let memoMatched = candidates.filter {
                !$0.memo.isEmpty
                    && (trimmed.isEmpty || $0.memo.localizedCaseInsensitiveContains(trimmed))
            }
            return SearchResults(entries: [], memos: memoMatched, comments: [])
        }

        // コメントスコープ: コメントだけをコメントセクションに表示
        if selectedScope == .comment {
            let allComments = viewModel.allComments()
            let commentMatched: [(MangaComment, MangaEntry)] = allComments.compactMap { comment in
                guard candidateIDs.contains(comment.mangaEntryID),
                      let entry = entriesByID[comment.mangaEntryID] else { return nil }
                if !trimmed.isEmpty,
                   !comment.content.localizedCaseInsensitiveContains(trimmed) {
                    return nil
                }
                return (comment, entry)
            }
            return SearchResults(entries: [], memos: [], comments: commentMatched)
        }

        // クエリ未入力時はマンガセクションだけ
        guard !trimmed.isEmpty else {
            return SearchResults(entries: candidates, memos: [], comments: [])
        }

        // 通常スコープ: 3 セクションに分類
        // 1. マンガ名/掲載誌マッチ
        let nameMatched = candidates.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.publisher.localizedCaseInsensitiveContains(trimmed)
        }

        // 2. メモマッチ（マンガ名にヒットしていても独立して表示する）
        let memoMatched = candidates.filter {
            !$0.memo.isEmpty
                && $0.memo.localizedCaseInsensitiveContains(trimmed)
        }

        // 3. コメントマッチ
        let allComments = viewModel.allComments()
        let commentMatched: [(MangaComment, MangaEntry)] = allComments.compactMap { comment in
            guard candidateIDs.contains(comment.mangaEntryID),
                  comment.content.localizedCaseInsensitiveContains(trimmed),
                  let entry = entriesByID[comment.mangaEntryID] else { return nil }
            return (comment, entry)
        }

        return SearchResults(entries: nameMatched, memos: memoMatched, comments: commentMatched)
    }

    private func applyColorFilter(to entries: [MangaEntry]) -> [MangaEntry] {
        guard !selectedColors.isEmpty else { return entries }
        return entries.filter { selectedColors.contains($0.iconColor) }
    }

    private func applyScope(to entries: [MangaEntry]) -> [MangaEntry] {
        switch selectedScope {
        case .all: return entries
        case .unread: return entries.filter { !$0.isRead }
        case .backlog: return entries.filter { $0.readingState == .backlog }
        case .serial: return entries.filter {
            !$0.isOneShot
                && $0.publicationStatus == .active
                && $0.readingState == .following
        }
        case .hiatus: return entries.filter {
            $0.publicationStatus == .hiatus && $0.readingState != .archived
        }
        case .publicationFinished: return entries.filter {
            $0.publicationStatus == .finished && $0.readingState != .archived
        }
        case .archived: return entries.filter { $0.readingState == .archived }
        case .oneShot: return entries.filter {
            $0.isOneShot && $0.readingState != .archived
        }
        // メモ・コメントスコープはエントリ自体は絞り込まない（曜日/カラーのみ）
        case .memo, .comment: return entries
        }
    }

    private func applyDayFilter(to entries: [MangaEntry]) -> [MangaEntry] {
        guard let day = selectedDay else { return entries }
        return entries.filter { $0.dayOfWeek == day }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if ThemeManager.shared.style.usesCustomSurface {
                    ThemeManager.shared.style.surface
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    scopeTabBar
                    colorFilterBar
                    content
                }
            }
            .navigationTitle("検索")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "マンガ名・掲載誌で検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            selectedDay = nil
                        } label: {
                            HStack {
                                Text("すべての曜日")
                                if selectedDay == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Divider()
                        ForEach(DayOfWeek.orderedDays) { day in
                            Button {
                                selectedDay = day
                            } label: {
                                HStack {
                                    Text(day.displayName)
                                    if selectedDay == day {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: selectedDay == nil ? "calendar" : "calendar.badge.checkmark")
                    }
                }
            }
            .sheet(item: $editingEntry) { entry in
                if let viewModel {
                    EditEntryView(viewModel: viewModel, entry: entry)
                }
            }
            .sheet(item: $commentingEntry) { entry in
                if let viewModel {
                    CommentListView(entry: entry, viewModel: viewModel)
                }
            }
            #if canImport(UIKit)
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            #endif
        }
        .onAppear {
            if viewModel == nil {
                viewModel = MangaViewModel(modelContext: modelContext)
            }
        }
        .onMangaDataChange {
            viewModel?.refresh()
        }
    }

    @ViewBuilder
    private var colorFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MangaColor.all) { mangaColor in
                    let isSelected = selectedColors.contains(mangaColor.name)
                    let label = colorLabelStore.label(for: mangaColor.name)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isSelected {
                                selectedColors.remove(mangaColor.name)
                            } else {
                                selectedColors.insert(mangaColor.name)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(mangaColor.color)
                                .frame(width: 14, height: 14)
                            if let label {
                                Text(label)
                                    .font(theme.captionFont)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                                ? AnyShapeStyle(theme.primary.opacity(0.2))
                                : AnyShapeStyle(theme.surfaceContainerHigh)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? theme.primary : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(theme.onSurface)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var scopeTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases) { scope in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedScope = scope
                        }
                    } label: {
                        Text(scope.rawValue)
                            .font(theme.bodyFont)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedScope == scope
                                    ? AnyShapeStyle(theme.primary)
                                    : AnyShapeStyle(theme.surfaceContainerHigh)
                            )
                            .foregroundStyle(
                                selectedScope == scope
                                    ? theme.onPrimary
                                    : theme.onSurface
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel == nil {
            EmptyView()
        } else {
            let results = searchResults
            if results.isEmpty {
                emptyState
            } else {
                resultList(results: results)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty && selectedScope == .all && selectedDay == nil && selectedColors.isEmpty {
            ContentUnavailableView {
                Label("検索", systemImage: "magnifyingglass")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("マンガ名・掲載誌・メモ・コメントから検索できます\n下のスコープで絞り込みも可能")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        } else if trimmed.isEmpty && selectedScope == .memo {
            ContentUnavailableView {
                Label("メモがありません", systemImage: "note.text")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("編集画面の「メモ」セクションから書けます")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        } else if trimmed.isEmpty && selectedScope == .comment {
            ContentUnavailableView {
                Label("コメントがありません", systemImage: "bubble.left.and.bubble.right")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("マンガを長押し →「コメント」から投稿できます")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        } else {
            ContentUnavailableView.search(text: trimmed)
        }
    }

    @ViewBuilder
    private func resultList(results: SearchResults) -> some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        List {
            if !results.entries.isEmpty {
                Section {
                    ForEach(results.entries, id: \.id) { entry in
                        SearchResultRow(
                            entry: entry,
                            viewModel: viewModel!,
                            editingEntry: $editingEntry,
                            commentingEntry: $commentingEntry,
                            onOpenURL: openMangaURL
                        )
                    }
                } header: {
                    sectionHeader(title: "マンガ", count: results.entries.count)
                }
            }

            if !results.memos.isEmpty {
                Section {
                    ForEach(results.memos, id: \.id) { entry in
                        MemoMatchRow(
                            entry: entry,
                            query: trimmed,
                            editingEntry: $editingEntry
                        )
                    }
                } header: {
                    sectionHeader(title: "メモ", count: results.memos.count)
                }
            }

            if !results.comments.isEmpty {
                Section {
                    ForEach(results.comments, id: \.comment.id) { match in
                        CommentMatchRow(
                            comment: match.comment,
                            entry: match.entry,
                            query: trimmed,
                            commentingEntry: $commentingEntry
                        )
                    }
                } header: {
                    sectionHeader(title: "コメント", count: results.comments.count)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(theme.subheadlineFont.bold())
                .foregroundStyle(theme.onSurface)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.onPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(theme.primary)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(urlString)
    }
}
