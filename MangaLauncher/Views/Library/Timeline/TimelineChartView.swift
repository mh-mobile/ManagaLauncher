import SwiftUI
import Charts

/// TimelineView 上部のコンパクトな棒グラフ。
/// granularity (週 / 月) で期間を切替、種別を積み上げ、棒タップで selectedDate を更新。
/// 長押し (Chart 標準の selection gesture) で tooltip に件数内訳を表示。
struct TimelineChartView: View {
    @Binding var selectedDate: Date
    let granularity: TimelineChartGranularity
    let counts: [TimelineDailyCount]

    /// selection gesture で hover/長押しされた日付
    @State private var hoveredDate: Date?

    private let chartHeight: CGFloat = 80

    private var theme: ThemeStyle { ThemeManager.shared.style }

    // MARK: - Aggregates

    private var totalCount: Int { counts.reduce(0) { $0 + $1.count } }

    private func total(for kind: TimelineItemKind) -> Int {
        counts.filter { $0.kind == kind }.reduce(0) { $0 + $1.count }
    }

    private var isEmpty: Bool { totalCount == 0 }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            summaryLine
            chartBody
        }
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
        .animation(.easeInOut(duration: 0.3), value: granularity)
        .animation(.easeInOut(duration: 0.3), value: counts)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Summary line

    @ViewBuilder
    private var summaryLine: some View {
        HStack(spacing: 8) {
            Text(granularity == .week ? "今週" : "今月")
                .font(theme.captionFont)
                .foregroundStyle(theme.onSurfaceVariant)
            Text("\(totalCount) 件")
                .font(theme.subheadlineFont.weight(.semibold))
                .foregroundStyle(theme.onSurface)
                .contentTransition(.numericText())
            if totalCount > 0 {
                Text(breakdownText)
                    .font(theme.captionFont)
                    .foregroundStyle(theme.onSurfaceVariant)
            }
            Spacer()
        }
    }

    private var breakdownText: String {
        let parts = TimelineItemKind.allCases.compactMap { kind -> String? in
            let count = total(for: kind)
            guard count > 0 else { return nil }
            return "\(kind.displayName) \(count)"
        }
        return "(\(parts.joined(separator: " / ")))"
    }

    // MARK: - Chart body

    @ViewBuilder
    private var chartBody: some View {
        ZStack {
            Chart(counts) { datum in
                BarMark(
                    x: .value("日", datum.date, unit: .day),
                    y: .value("件数", datum.count)
                )
                .foregroundStyle(by: .value("種別", datum.kind.displayName))
                .cornerRadius(3)
                .opacity(isSelected(datum.date) ? 1.0 : 0.55)

                if let hoveredDate, Calendar.current.isDate(datum.date, inSameDayAs: hoveredDate) {
                    RuleMark(x: .value("選択", datum.date, unit: .day))
                        .foregroundStyle(theme.onSurface.opacity(0.25))
                        .offset(yStart: -6)
                        .zIndex(-1)
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            tooltip(for: hoveredDate)
                        }
                }
            }
            .chartForegroundStyleScale([
                TimelineItemKind.comment.displayName: Color.blue,
                TimelineItemKind.memo.displayName: Color.orange,
                TimelineItemKind.read.displayName: Color.green
            ])
            .chartXAxis { xAxis }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartXSelection(value: $hoveredDate)
            .frame(height: chartHeight)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, proxy: proxy, geo: geo)
                        }
                }
            }

            if isEmpty {
                Text("この\(granularity.displayName)はアクティビティがありません")
                    .font(theme.captionFont)
                    .foregroundStyle(theme.onSurfaceVariant)
            }
        }
    }

    private var xAxis: some AxisContent {
        AxisMarks(values: xAxisValues) { value in
            if let date = value.as(Date.self) {
                AxisValueLabel {
                    Text(axisLabel(for: date))
                        .font(.caption2.weight(isToday(date) ? .bold : .regular))
                        .foregroundStyle(labelColor(for: date))
                }
            }
        }
    }

    /// 週: 7 日全て表示。月: 週次 (月曜) だけ表示してラベル過密を防ぐ。
    private var xAxisValues: [Date] {
        let uniqueDates = counts.map(\.date).unique()
        switch granularity {
        case .week:
            return uniqueDates
        case .month:
            var cal = Calendar(identifier: .gregorian)
            cal.firstWeekday = 2
            return uniqueDates.filter { cal.component(.weekday, from: $0) == 2 }
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch granularity {
        case .week: return Self.weekdayFormatter.string(from: date)
        case .month: return Self.dayFormatter.string(from: date)
        }
    }

    private func labelColor(for date: Date) -> Color {
        if isSelected(date) { return theme.primary }
        if isToday(date) { return theme.onSurface }
        return .secondary
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltip(for date: Date) -> some View {
        let dayCounts = counts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let dayTotal = dayCounts.reduce(0) { $0 + $1.count }
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.tooltipDateFormatter.string(from: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(dayTotal) 件")
                .font(.caption.weight(.semibold))
            ForEach(TimelineItemKind.allCases) { kind in
                let c = dayCounts.first(where: { $0.kind == kind })?.count ?? 0
                if c > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(color(for: kind)).frame(width: 6, height: 6)
                        Text("\(kind.displayName) \(c)")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.surfaceContainerHighest)
                .shadow(radius: 2)
        )
    }

    // MARK: - Helpers

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func color(for kind: TimelineItemKind) -> Color {
        switch kind {
        case .comment: .blue
        case .memo: .orange
        case .read: .green
        }
    }

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plot = proxy.plotFrame else { return }
        let plotFrame = geo[plot]
        let relativeX = location.x - plotFrame.origin.x
        guard relativeX >= 0, relativeX <= plotFrame.width else { return }
        guard let date: Date = proxy.value(atX: relativeX) else { return }
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    // MARK: - Accessibility

    private var accessibilitySummary: String {
        let period = granularity.displayName
        if isEmpty {
            return "この\(period)はアクティビティがありません"
        }
        let parts = TimelineItemKind.allCases.map { "\($0.displayName) \(total(for: $0)) 件" }
        return "この\(period)のアクティビティ合計 \(totalCount) 件。" + parts.joined(separator: "、")
    }

    // MARK: - Formatters

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "E"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let tooltipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f
    }()
}

private extension Array where Element: Hashable {
    /// 先頭からの出現順を保って重複を取り除く。
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
