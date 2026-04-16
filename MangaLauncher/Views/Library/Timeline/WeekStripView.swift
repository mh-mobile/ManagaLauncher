import SwiftUI

/// タイムライン上部の曜日ストリップ。横スワイプで週を切替、日付タップで選択。
/// アクティビティがあった日は日付下にドットを出す。
struct WeekStripView: View {
    @Binding var selectedDate: Date
    /// startOfDay 済みの日付集合。親が TimelineBuilder.activeDays で計算して渡す。
    let activeDays: Set<Date>

    /// 表示中の週オフセット (0 = 今週、-1 = 先週)
    @State private var weekOffset: Int = 0

    /// 月曜はじまりの週。firstWeekday = 2
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }()

    /// 過去 26 週 + 今週 + 未来 1 週 までをページング可能に。
    private let pageRange = -26...1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            monthHeader
            TabView(selection: $weekOffset) {
                ForEach(pageRange, id: \.self) { offset in
                    weekRow(for: offset)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 68)
        }
        .onChange(of: selectedDate) { _, newDate in
            // 月 grid などで外から selectedDate が変わったとき、
            // その週に表示を追従させる
            let target = computeWeekOffset(for: newDate)
            if target != weekOffset {
                withAnimation { weekOffset = target }
            }
        }
        .onAppear {
            weekOffset = computeWeekOffset(for: selectedDate)
        }
    }

    // MARK: - Header (year/month of visible week)

    private var monthHeader: some View {
        let firstDay = weekStart(for: weekOffset)
        return Text(Self.monthFormatter.string(from: firstDay))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    // MARK: - Week row

    private func weekRow(for offset: Int) -> some View {
        let start = weekStart(for: offset)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Day cell

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasActivity = activeDays.contains(calendar.startOfDay(for: day))

        return VStack(spacing: 3) {
            Text(Self.weekdayFormatter.string(from: day))
                .font(.caption2)
                .foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 30, height: 30)
                if isToday && !isSelected {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }
                Text(Self.dayFormatter.string(from: day))
                    .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            Circle()
                .fill(hasActivity ? Color.accentColor.opacity(0.7) : Color.clear)
                .frame(width: 4, height: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = calendar.startOfDay(for: day)
        }
    }

    // MARK: - Date math

    private func weekStart(for offset: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let thisWeekStart = calendar.date(from: components) ?? today
        return calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeekStart) ?? thisWeekStart
    }

    /// 与えられた日付が属する週の、今週との差 (週単位)。
    private func computeWeekOffset(for date: Date) -> Int {
        let dateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let todayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let dateWeekStart = calendar.date(from: dateComponents),
              let todayWeekStart = calendar.date(from: todayComponents) else { return 0 }
        let weeks = calendar.dateComponents([.weekOfYear], from: todayWeekStart, to: dateWeekStart).weekOfYear ?? 0
        // ページング範囲にクランプ
        return max(pageRange.lowerBound, min(pageRange.upperBound, weeks))
    }

    // MARK: - Formatters

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f
    }()

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
}
