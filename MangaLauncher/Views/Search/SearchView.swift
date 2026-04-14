import SwiftUI
import SwiftData
import PlatformKit

struct SearchView: View {
    @Environment(\.openURL) private var openURL

    var viewModel: MangaViewModel
    @State private var searchText: String = ""

    // MARK: - 2 軸フィルタ（各グループ内は単一選択）
    @State private var publicationFilter: PublicationStatus? = nil
    @State private var readingFilter: ReadingState? = nil
    @State private var showOneShotOnly = false  // 掲載状況と排他
    @State private var contentMode: SearchContentMode = .entries

    @State private var selectedDay: DayOfWeek? = nil
    @State private var selectedColors: Set<String> = []
    @State private var safariURL: URL?
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @AppStorage("browserMode") private var browserMode: String = "external"

    private let colorLabelStore = ColorLabelStore.shared
    private var theme: ThemeStyle { ThemeManager.shared.style }

    enum SearchContentMode {
        case entries, memo, comment
    }

    // MARK: - Search Results

    private struct SearchResults {
        var entries: [MangaEntry]
        var memos: [MangaEntry]
        var comments: [(comment: MangaComment, entry: MangaEntry)]

        var isEmpty: Bool { entries.isEmpty && memos.isEmpty && comments.isEmpty }
    }

    private var searchResults: SearchResults {
        let allEntries = viewModel.allEntries()
        let dayFiltered = applyDayFilter(to: allEntries)
        let colorFiltered = applyColorFilter(to: dayFiltered)

        let trimmed = searchText.trimmingCharacters(in: .whitespaces)

        if contentMode == .memo {
            let memoMatched = colorFiltered.filter {
                !$0.memo.isEmpty
                    && (trimmed.isEmpty || $0.memo.localizedCaseInsensitiveContains(trimmed))
            }
            return SearchResults(entries: [], memos: memoMatched, comments: [])
        }

        if contentMode == .comment {
            let candidateIDs = Set(colorFiltered.map(\.id))
            let entriesByID = Dictionary(uniqueKeysWithValues: colorFiltered.map { ($0.id, $0) })
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

        let candidates = applyEntryFilters(to: colorFiltered)

        guard !trimmed.isEmpty else {
            return SearchResults(entries: candidates, memos: [], comments: [])
        }

        let nameMatched = candidates.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.publisher.localizedCaseInsensitiveContains(trimmed)
        }
        let memoMatched = candidates.filter {
            !$0.memo.isEmpty
                && $0.memo.localizedCaseInsensitiveContains(trimmed)
        }
        let filteredIDs = Set(candidates.map(\.id))
        let entriesByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let allComments = viewModel.allComments()
        let commentMatched: [(MangaComment, MangaEntry)] = allComments.compactMap { comment in
            guard filteredIDs.contains(comment.mangaEntryID),
                  comment.content.localizedCaseInsensitiveContains(trimmed),
                  let entry = entriesByID[comment.mangaEntryID] else { return nil }
            return (comment, entry)
        }

        return SearchResults(entries: nameMatched, memos: memoMatched, comments: commentMatched)
    }

    // MARK: - Filter Logic

    private func applyEntryFilters(to entries: [MangaEntry]) -> [MangaEntry] {
        var filtered = entries
        if let pub = publicationFilter {
            filtered = filtered.filter { $0.publicationStatus == pub }
        }
        if let read = readingFilter {
            filtered = filtered.filter { $0.readingState == read }
        }
        if showOneShotOnly {
            filtered = filtered.filter { $0.isOneShot }
        }
        return filtered
    }

    private func applyColorFilter(to entries: [MangaEntry]) -> [MangaEntry] {
        guard !selectedColors.isEmpty else { return entries }
        return entries.filter { selectedColors.contains($0.iconColor) }
    }

    private func applyDayFilter(to entries: [MangaEntry]) -> [MangaEntry] {
        guard let day = selectedDay else { return entries }
        return entries.filter { $0.dayOfWeek == day }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if ThemeManager.shared.style.usesCustomSurface {
                    ThemeManager.shared.style.surface
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    stateFilterBar
                    secondaryFilterBar
                    content
                }
            }
            .navigationTitle("検索")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "マンガ・メモ・コメントを検索")
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
                EditEntryView(viewModel: viewModel, entry: entry)
            }
            .sheet(item: $commentingEntry) { entry in
                CommentListView(entry: entry, viewModel: viewModel)
            }
            #if canImport(UIKit)
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            #endif
        }
        .onMangaDataChange {
            viewModel.refresh()
        }
    }

    // MARK: - 行 1: 状態フィルタ（2 軸）

    @ViewBuilder
    private var stateFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // 掲載状況 + 読み切り（排他グループ）
                ForEach(PublicationStatus.allCases) { status in
                    filterChip(label: status.displayName, isSelected: !showOneShotOnly && publicationFilter == status) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            contentMode = .entries
                            showOneShotOnly = false
                            publicationFilter = publicationFilter == status ? nil : status
                        }
                    }
                }
                filterChip(label: "読み切り", isSelected: showOneShotOnly) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        contentMode = .entries
                        if showOneShotOnly {
                            showOneShotOnly = false
                        } else {
                            showOneShotOnly = true
                            publicationFilter = nil  // 掲載状況をクリア
                        }
                    }
                }

                Spacer().frame(width: 12)

                // 読書状況
                ForEach(ReadingState.allCases) { state in
                    filterChip(label: state.displayName, isSelected: readingFilter == state) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            contentMode = .entries
                            readingFilter = readingFilter == state ? nil : state
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 行 2: 種別 + メモ/コメント + カラーフィルタ

    @ViewBuilder
    private var secondaryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // メモ/コメントモード
                filterChip(label: "メモ", isSelected: contentMode == .memo) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if contentMode == .memo {
                            contentMode = .entries
                        } else {
                            contentMode = .memo
                            clearEntryFilters()
                        }
                    }
                }
                filterChip(label: "コメント", isSelected: contentMode == .comment) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if contentMode == .comment {
                            contentMode = .entries
                        } else {
                            contentMode = .comment
                            clearEntryFilters()
                        }
                    }
                }

                // カラーフィルタ
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

    // MARK: - Helpers

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(theme.bodyFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? AnyShapeStyle(theme.primary)
                        : AnyShapeStyle(theme.surfaceContainerHigh)
                )
                .foregroundStyle(isSelected ? theme.onPrimary : theme.onSurface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func clearEntryFilters() {
        publicationFilter = nil
        readingFilter = nil
        showOneShotOnly = false
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let results = searchResults
        if results.isEmpty {
            emptyState
        } else {
            resultList(results: results)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let hasAnyFilter = publicationFilter != nil || readingFilter != nil
            || showOneShotOnly || selectedDay != nil || !selectedColors.isEmpty

        if trimmed.isEmpty && !hasAnyFilter && contentMode == .entries {
            ContentUnavailableView {
                Label("検索", systemImage: "magnifyingglass")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("マンガ名・掲載誌・メモ・コメントから検索できます\nフィルタで絞り込みも可能")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        } else if trimmed.isEmpty && contentMode == .memo {
            ContentUnavailableView {
                Label("メモがありません", systemImage: "note.text")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("編集画面の「メモ」セクションから書けます")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        } else if trimmed.isEmpty && contentMode == .comment {
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

    // MARK: - Result List

    @ViewBuilder
    private func resultList(results: SearchResults) -> some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        List {
            if !results.entries.isEmpty {
                Section {
                    ForEach(results.entries, id: \.id) { entry in
                        SearchResultRow(
                            entry: entry,
                            viewModel: viewModel,
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
