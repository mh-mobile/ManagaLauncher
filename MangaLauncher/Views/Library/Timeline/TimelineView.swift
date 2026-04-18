import SwiftUI

/// 1 日のアクティビティ (コメント / メモ / 既読) を時系列に並べる画面。
/// WeekStripView で日付切替、ActivityCalendarView で月 grid ピッカー、
/// TimelineFilter で種別フィルタを提供する。
struct TimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var viewModel: MangaViewModel
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @State private var safariURL: URL?
    @State private var filter: TimelineFilter = .all
    @State private var showingMonthPicker = false
    @State private var chartGranularity: TimelineChartGranularity = .week
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"

    @State private var pageAnchor: Date = Calendar.current.startOfDay(for: Date())

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private static let pageRadius = 90

    var body: some View {
        let _ = viewModel.refreshCounter
        let allEntries = viewModel.allEntries()
        let allComments = viewModel.allComments()
        let allActivities = viewModel.allActivities()
        let activeDays = TimelineBuilder.activeDays(
            entries: allEntries,
            comments: allComments,
            activities: allActivities
        )
        let dates = pageDates()

        return VStack(alignment: .leading, spacing: 0) {
            WeekStripView(selectedDate: $selectedDate, activeDays: activeDays)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(
                    theme.usesCustomSurface ? AnyView(theme.surface) : AnyView(Color(uiColor: .systemBackground))
                )
            Divider()

            VStack(alignment: .leading, spacing: 16) {
                header
                chartBlock(entries: allEntries, comments: allComments, activities: allActivities)
                filterChips
            }
            .padding(.horizontal)
            .padding(.top, 12)

            TabView(selection: $selectedDate) {
                ForEach(dates, id: \.self) { date in
                    TimelineDatePage(
                        date: date,
                        filter: $filter,
                        allEntries: allEntries,
                        allComments: allComments,
                        allActivities: allActivities,
                        onTap: { handleTap(on: $0) }
                    )
                    .tag(date)
                }
            }
            #if os(iOS) || os(visionOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
        }
        .background(
            theme.usesCustomSurface ? AnyView(theme.surface.ignoresSafeArea()) : AnyView(Color.clear)
        )
        .background { InteractivePopDisabler() }
        .navigationTitle("タイムライン")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                        Text("戻る")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingMonthPicker = true
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            reanchorIfNeeded(for: newDate)
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

    // MARK: - Fixed sections

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.dayOfMonthFormatter.string(from: selectedDate))
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(theme.onSurface)
                .contentTransition(.numericText())
            Text(Self.monthYearFormatter.string(from: selectedDate))
                .font(theme.subheadlineFont)
                .foregroundStyle(theme.onSurfaceVariant)
        }
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
    }

    @ViewBuilder
    private func chartBlock(
        entries: [MangaEntry],
        comments: [MangaComment],
        activities: [ReadingActivity]
    ) -> some View {
        let allCounts = TimelineBuilder.dailyCounts(
            days: chartGranularity.days(containing: selectedDate),
            entries: entries,
            comments: comments,
            activities: activities
        )
        let counts = filter.kind.map { kind in allCounts.filter { $0.kind == kind } } ?? allCounts
        VStack(alignment: .leading, spacing: 8) {
            Picker("期間", selection: $chartGranularity) {
                ForEach(TimelineChartGranularity.allCases) { g in
                    Text(g.displayName).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)

            TimelineChartView(
                selectedDate: $selectedDate,
                granularity: chartGranularity,
                counts: counts
            )
        }
    }

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

    // MARK: - Paging helpers

    private func pageDates() -> [Date] {
        let calendar = Calendar.current
        return (-Self.pageRadius...Self.pageRadius).map {
            calendar.date(byAdding: .day, value: $0, to: pageAnchor)!
        }
    }

    private func reanchorIfNeeded(for date: Date) {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: pageAnchor, to: date).day ?? 0
        if abs(days) > Self.pageRadius - 15 {
            pageAnchor = calendar.startOfDay(for: date)
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
            guard let entry else { return }
            MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(entry.url)
        }
    }

    // MARK: - Formatters

    static let dayOfMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "d日 (EEE)"
        return f
    }()

    static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f
    }()
}

// MARK: - Swipeable timeline items (per-date page)

private struct TimelineDatePage: View {
    let date: Date
    @Binding var filter: TimelineFilter
    let allEntries: [MangaEntry]
    let allComments: [MangaComment]
    let allActivities: [ReadingActivity]
    let onTap: (TimelineItem) -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        let allItems = TimelineBuilder.items(
            for: date,
            entries: allEntries,
            comments: allComments,
            activities: allActivities
        )
        let items = filter.apply(to: allItems)

        ScrollView {
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
                            onTap: { onTap(item) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }

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
                Button("すべて表示") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        filter = .all
                    }
                }
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
}

// MARK: - Disable interactive pop gesture

#if canImport(UIKit)
private struct InteractivePopDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PopDisablerController {
        PopDisablerController()
    }
    func updateUIViewController(_ controller: PopDisablerController, context: Context) {}
}

private final class PopDisablerController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}
#endif
