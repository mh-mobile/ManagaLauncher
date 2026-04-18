import SwiftUI
import PlatformKit

struct MangaLifetimeView: View {
    @Environment(\.openURL) private var openURL
    let lifetimes: [MangaLifetime]
    var viewModel: MangaViewModel
    @State private var selectedLifetime: MangaLifetime?
    @State private var chartAreaWidth: CGFloat = 0
    @State private var safariURL: URL?
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"

    private var theme: ThemeStyle { ThemeManager.shared.style }
    private let thumbnailSize: CGFloat = 32
    private let rowHeight: CGFloat = 36
    private let barHeight: CGFloat = 14

    var body: some View {
        if lifetimes.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader
                axisRow
                scrollableContent
            }
            .sheet(item: $selectedLifetime) { lifetime in
                LifetimeDetailSheet(lifetime: lifetime, viewModel: viewModel)
            }
            #if canImport(UIKit)
            .sheet(item: $safariURL) { url in
                SafariView(url: url).ignoresSafeArea()
            }
            #endif
        }
    }

    @ViewBuilder
    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(theme.primary)
            Text("マンガライフタイム")
                .font(theme.subheadlineFont.weight(.semibold))
                .foregroundStyle(theme.onSurface)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            sectionHeader
            Text("アクティビティのある作品がありません")
                .font(theme.captionFont)
                .foregroundStyle(theme.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        }
    }

    // MARK: - Time axis & bar rows (horizontally scrollable)

    private var contentWidth: CGFloat {
        let days = Int(totalDays)
        let minWidth = chartAreaWidth
        let pixelsPerDay: CGFloat = 8
        return max(CGFloat(days) * pixelsPerDay, minWidth)
    }

    @ViewBuilder
    private var axisRow: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: thumbnailSize)
            GeometryReader { geo in
                Color.clear.onAppear { chartAreaWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in chartAreaWidth = w }
            }
        }
        .frame(height: 0)
    }

    @ViewBuilder
    private var scrollableContent: some View {
        HStack(alignment: .top, spacing: 8) {
            // Fixed left: thumbnails
            VStack(spacing: 0) {
                Color.clear.frame(height: 16)
                ForEach(lifetimes) { lifetime in
                    thumbnail(for: lifetime.entry)
                        .frame(height: rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { openMangaURL(lifetime.entry.url) }
                }
            }
            .frame(width: thumbnailSize)

            // Scrollable right: axis + bars
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .leading) {
                        let labels = axisLabels()
                        ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                            Text(label.text)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.onSurfaceVariant)
                                .position(x: label.fraction * contentWidth, y: 8)
                        }
                    }
                    .frame(width: contentWidth, height: 16)

                    ForEach(lifetimes) { lifetime in
                        barContent(lifetime: lifetime)
                            .frame(height: rowHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedLifetime = lifetime }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func barContent(lifetime: MangaLifetime) -> some View {
        let startFrac = dayFraction(for: lifetime.startDate)
        let endFrac = dayFraction(for: lifetime.endDate)
        let barWidth = max((endFrac - startFrac) * contentWidth, 6)

        ZStack(alignment: .leading) {
            Color.clear.frame(width: contentWidth)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.fromName(lifetime.entry.iconColor).opacity(lifetime.isActive ? 0.8 : 0.5))
                .frame(width: barWidth, height: barHeight)
                .offset(x: startFrac * contentWidth)
        }
        .frame(height: barHeight)
    }

    @ViewBuilder
    private func thumbnail(for entry: MangaEntry) -> some View {
        Group {
            if let data = entry.imageData, let image = data.toSwiftUIImage() {
                image.resizable().scaledToFill()
            } else {
                Color.fromName(entry.iconColor)
                    .overlay {
                        Text(entry.name.prefix(1))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(urlString)
    }

    // MARK: - Domain

    private var domainStart: Date {
        let earliest = lifetimes.map(\.startDate).min() ?? Date()
        return Calendar.current.date(byAdding: .day, value: -1, to: earliest) ?? earliest
    }

    private var domainEnd: Date {
        let latest = lifetimes.map(\.endDate).max() ?? Date()
        return Calendar.current.date(byAdding: .day, value: 2, to: latest) ?? latest
    }

    private var totalDays: CGFloat {
        CGFloat(max(Calendar.current.dateComponents([.day], from: domainStart, to: domainEnd).day ?? 1, 1))
    }

    private func dayFraction(for date: Date) -> CGFloat {
        let days = Calendar.current.dateComponents([.day], from: domainStart, to: date).day ?? 0
        return CGFloat(days) / totalDays
    }

    // MARK: - Axis labels

    private func axisLabels() -> [(text: String, fraction: CGFloat)] {
        let days = Int(totalDays)
        let calendar = Calendar.current

        if days > 365 {
            return monthBoundaries().map {
                (Self.yearMonthFormatter.string(from: $0), dayFraction(for: $0))
            }
        } else if days > 60 {
            return monthBoundaries().map {
                (Self.monthFormatter.string(from: $0), dayFraction(for: $0))
            }
        } else {
            let stride = max(days / 4, 1)
            var result: [(String, CGFloat)] = []
            var i = stride
            while i < days {
                let date = calendar.date(byAdding: .day, value: i, to: domainStart) ?? domainStart
                result.append((Self.dayFormatter.string(from: date), dayFraction(for: date)))
                i += stride
            }
            return result
        }
    }

    private func monthBoundaries() -> [Date] {
        let calendar = Calendar.current
        var result: [Date] = []
        var comps = calendar.dateComponents([.year, .month], from: domainStart)
        comps.month! += 1
        while let date = calendar.date(from: comps), date < domainEnd {
            result.append(date)
            comps.month! += 1
        }
        return result
    }

    // MARK: - Formatters

    private static let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yy/M"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        return f
    }()
}

// MARK: - Detail sheet

struct LifetimeDetailSheet: View {
    let lifetime: MangaLifetime
    var viewModel: MangaViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"
    @State private var safariURL: URL?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        NavigationStack {
            let items = buildItems()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    periodHeader
                    if items.isEmpty {
                        ContentUnavailableView {
                            Label("イベントなし", systemImage: "calendar.badge.clock")
                                .foregroundStyle(theme.onSurfaceVariant)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                let showDate = index == 0 || !Calendar.current.isDate(item.timestamp, inSameDayAs: items[index - 1].timestamp)
                                eventRow(item: item, index: index, total: items.count, showDate: showDate)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .themedNavigationStyle()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        openDetailURL(lifetime.entry.url)
                    } label: {
                        HStack(spacing: 8) {
                            entryThumbnail
                            Text(lifetime.entry.name)
                                .font(theme.subheadlineFont.weight(.semibold))
                                .foregroundStyle(theme.onSurface)
                                .lineLimit(1)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .sheet(item: $safariURL) { url in
                SafariView(url: url).ignoresSafeArea()
            }
            #endif
        }
        .presentationDetents([.medium, .large])
    }

    private func openDetailURL(_ urlString: String) {
        MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(urlString)
    }

    @ViewBuilder
    private var periodHeader: some View {
        HStack(spacing: 4) {
            Text(Self.dateFormatter.string(from: lifetime.startDate))
            Text("〜")
            Text(lifetime.isActive ? "現在" : Self.dateFormatter.string(from: lifetime.endDate))
        }
        .font(theme.captionFont)
        .foregroundStyle(theme.onSurfaceVariant)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func eventRow(item: TimelineItem, index: Int, total: Int, showDate: Bool) -> some View {
        let isFirst = index == 0
        let isLast = index == total - 1
        let lineColor = theme.onSurfaceVariant.opacity(0.25)

        HStack(alignment: .top, spacing: 0) {
            // Left: date column
            VStack {
                if showDate {
                    Text(Self.sectionDateFormatter.string(from: item.timestamp))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.onSurfaceVariant)
                }
            }
            .frame(width: 56, alignment: .trailing)
            .padding(.top, 2)

            // Middle: connector
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : lineColor)
                    .frame(width: 2, height: 8)
                Image(systemName: iconName(for: item))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(iconColor(for: item), in: Circle())
                Rectangle()
                    .fill(isLast ? Color.clear : lineColor)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 18)
            .padding(.horizontal, 8)

            // Right: content card
            VStack(alignment: .leading, spacing: 2) {
                Text(eventText(for: item))
                    .font(theme.captionFont)
                    .foregroundStyle(theme.onSurface)
                Text(Self.timeFormatter.string(from: item.timestamp))
                    .font(theme.caption2Font)
                    .foregroundStyle(theme.onSurfaceVariant)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.surfaceContainerHigh)
            )
            .padding(.vertical, 3)
        }
    }

    private func iconName(for item: TimelineItem) -> String {
        switch item {
        case .comment: "bubble.left.fill"
        case .memo: "pencil"
        case .read(let activity, _):
            activity.episodeNumber != nil ? "book.fill" : "checkmark"
        }
    }

    @ViewBuilder
    private var entryThumbnail: some View {
        Group {
            if let data = lifetime.entry.imageData, let image = data.toSwiftUIImage() {
                image.resizable().scaledToFill()
            } else {
                Color.fromName(lifetime.entry.iconColor)
                    .overlay {
                        Text(lifetime.entry.name.prefix(1))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func iconColor(for item: TimelineItem) -> Color {
        switch item {
        case .comment: .blue
        case .memo: .orange
        case .read(let activity, _):
            activity.episodeNumber != nil ? .purple : .green
        }
    }

    private func eventText(for item: TimelineItem) -> String {
        switch item {
        case .comment(let comment, _):
            comment.content
        case .memo(let entry):
            entry.memo.isEmpty ? "(空)" : entry.memo
        case .read(let activity, _):
            if let ep = activity.episodeNumber {
                "既読 \(ep)話に更新"
            } else {
                "読みました"
            }
        }
    }

    private func buildItems() -> [TimelineItem] {
        let entryID = lifetime.entry.id
        let allActivities = viewModel.allActivities().filter { $0.mangaEntryID == entryID }
        let allComments = viewModel.allComments().filter { $0.mangaEntryID == entryID }

        var items: [TimelineItem] = []
        for activity in allActivities {
            items.append(.read(activity, lifetime.entry))
        }
        for comment in allComments {
            items.append(.comment(comment, lifetime.entry))
        }
        if let _ = lifetime.entry.memoUpdatedAt, !lifetime.entry.memo.isEmpty {
            items.append(.memo(lifetime.entry))
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/M/d"
        return f
    }()

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

extension MangaLifetime: @retroactive Equatable {
    static func == (lhs: MangaLifetime, rhs: MangaLifetime) -> Bool {
        lhs.id == rhs.id
    }
}
