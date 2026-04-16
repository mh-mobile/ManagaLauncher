import SwiftUI

/// 1 日のアクティビティ (コメント / メモ / 既読) を時系列に並べる画面。
/// WeekStripView で日付切替、ActivityCalendarView で月 grid ピッカー、
/// TimelineFilter で種別フィルタを提供する。
struct TimelineView: View {
    @Environment(\.openURL) private var openURL
    var viewModel: MangaViewModel
    @State private var selectedDate: Date = Date()
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @State private var safariURL: URL?
    @State private var filter: TimelineFilter = .all
    @State private var showingMonthPicker = false
    @AppStorage("browserMode") private var browserMode: String = "external"

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        // 1 度だけ fetch して week strip とタイムラインで共有する
        let _ = viewModel.refreshCounter
        let allEntries = viewModel.allEntries()
        let allComments = viewModel.allComments()
        let allActivities = viewModel.allActivities()
        let activeDays = TimelineBuilder.activeDays(
            entries: allEntries,
            comments: allComments,
            activities: allActivities
        )

        return VStack(alignment: .leading, spacing: 0) {
            WeekStripView(selectedDate: $selectedDate, activeDays: activeDays)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(
                    theme.usesCustomSurface ? AnyView(theme.surface) : AnyView(Color(uiColor: .systemBackground))
                )
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    filterChips
                    timelineSection(entries: allEntries, comments: allComments, activities: allActivities)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(
            theme.usesCustomSurface ? AnyView(theme.surface.ignoresSafeArea()) : AnyView(Color.clear)
        )
        .navigationTitle("タイムライン")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingMonthPicker = true
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
        .sheet(isPresented: $showingMonthPicker) {
            NavigationStack {
                ActivityCalendarView(selectedDate: $selectedDate, activeDays: activeDays)
                    .padding()
                    .navigationTitle("日付を選択")
                    #if os(iOS) || os(visionOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") { showingMonthPicker = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
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
        .onMangaDataChange {
            viewModel.refresh()
        }
    }

    // MARK: - Filter chips

    @ViewBuilder
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineFilter.allCases) { option in
                    filterChip(for: option)
                }
            }
        }
    }

    private func filterChip(for option: TimelineFilter) -> some View {
        let isSelected = filter == option
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                filter = option
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: option.iconName)
                    .font(.caption2)
                Text(option.displayName)
                    .font(theme.captionFont.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : theme.surfaceContainerHigh)
            )
            .foregroundStyle(isSelected ? Color.white : theme.onSurface)
        }
        .buttonStyle(.plain)
    }


    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.dayOfMonthFormatter.string(from: selectedDate))
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(theme.onSurface)
            Text(Self.monthYearFormatter.string(from: selectedDate))
                .font(theme.subheadlineFont)
                .foregroundStyle(theme.onSurfaceVariant)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Timeline list

    @ViewBuilder
    private func timelineSection(
        entries: [MangaEntry],
        comments: [MangaComment],
        activities: [ReadingActivity]
    ) -> some View {
        let allItems = TimelineBuilder.items(
            for: selectedDate,
            entries: entries,
            comments: comments,
            activities: activities
        )
        let items = filter.apply(to: allItems)

        if items.isEmpty {
            emptyState(hasAnyItems: !allItems.isEmpty)
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TimelineRowView(
                        item: item,
                        isFirst: index == 0,
                        isLast: index == items.count - 1,
                        onTap: { handleTap(on: item) }
                    )
                }
            }
        }
    }

    /// 空状態。フィルタ適用で 0 件になった場合と、そもそも 0 件の場合を区別する。
    @ViewBuilder
    private func emptyState(hasAnyItems: Bool) -> some View {
        if hasAnyItems && filter != .all {
            ContentUnavailableView {
                Label("該当するアクティビティがありません", systemImage: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("フィルタ「\(filter.displayName)」に合うものはこの日にありません")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            } actions: {
                Button("すべて表示") { filter = .all }
            }
        } else {
            ContentUnavailableView {
                Label("この日はアクティビティがありません", systemImage: "calendar.badge.clock")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("コメント・メモ編集・既読の記録がここに並びます")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        }
    }

    // MARK: - Tap handling

    private func handleTap(on item: TimelineItem) {
        switch item {
        case .comment(_, let entry):
            commentingEntry = entry
        case .memo(let entry):
            editingEntry = entry
        case .read(_, let entry):
            // 「読みました」の再訪導線としてマンガサイトを開く。
            // entry が見つからないのは削除済みエントリの場合のみ (無視)。
            guard let entry else { return }
            MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(entry.url)
        }
    }

    // MARK: - Formatters

    private static let dayOfMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "d日 (EEE)"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f
    }()
}
