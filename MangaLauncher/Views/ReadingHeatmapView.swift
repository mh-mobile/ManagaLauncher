import SwiftUI
import SwiftData
import PlatformKit

struct ReadingHeatmapView: View {
    var viewModel: MangaViewModel

    private let weeks = 52
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    private let dayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    @State private var activityCounts: [Date: Int] = [:]
    @State private var selectedDate: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsSection
                heatmapSection
                legendSection
            }
            .padding()
        }
        .navigationTitle("読書アクティビティ")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            activityCounts = viewModel.fetchActivityCounts(days: weeks * 7)
        }
        .sheet(item: $selectedDate) { date in
            DayActivitySheet(date: date, viewModel: viewModel)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                statCard(title: "連続", value: "\(viewModel.currentStreak())", unit: "日")
                statCard(title: "最長", value: "\(viewModel.longestStreak())", unit: "日")
                statCard(title: "累計", value: "\(viewModel.totalReadCount())", unit: "話")
            }
            HStack(spacing: 16) {
                statCard(title: "今週", value: "\(viewModel.thisWeekReadCount())", unit: "話")
                statCard(title: "よく読む曜日", value: viewModel.mostActiveDay() ?? "-", unit: "")
            }
        }
    }

    private func statCard(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        let grid = buildGrid()
        let maxCount = activityCounts.values.max() ?? 1

        return HStack(alignment: .top, spacing: 4) {
            // Day labels (fixed)
            VStack(spacing: cellSpacing) {
                // Spacer for month label row
                Text("")
                    .font(.caption2)
                    .frame(height: 14)
                ForEach(0..<7, id: \.self) { dayIndex in
                    Text(dayLabels[dayIndex])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: cellSize)
                }
            }

            // Scrollable grid
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Month labels
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<weeks, id: \.self) { weekIndex in
                                let date = grid[weekIndex][0]
                                if let date, isFirstWeekOfMonth(date: date, weekIndex: weekIndex, grid: grid) {
                                    Text(monthLabel(for: date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                        .frame(width: cellSize, alignment: .leading)
                                } else {
                                    Text("")
                                        .frame(width: cellSize)
                                }
                            }
                        }
                        .frame(height: 14)

                        // Cells
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<weeks, id: \.self) { weekIndex in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<7, id: \.self) { dayIndex in
                                        if let date = grid[weekIndex][dayIndex] {
                                            let count = activityCounts[date] ?? 0
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(cellColor(count: count, maxCount: maxCount))
                                                .frame(width: cellSize, height: cellSize)
                                                .onTapGesture {
                                                    if count > 0 {
                                                        selectedDate = date
                                                    }
                                                }
                                        } else {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(.clear)
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                                .id(weekIndex)
                            }
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo(weeks - 1, anchor: .trailing)
                }
            }
        }
    }

    // MARK: - Legend

    private var legendSection: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("少ない")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor(level))
                    .frame(width: 12, height: 12)
            }
            Text("多い")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func buildGrid() -> [[Date?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find Monday of this week
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon, ...
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6
        let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let startMonday = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisMonday)!

        var grid: [[Date?]] = []
        for week in 0..<weeks {
            var column: [Date?] = []
            for day in 0..<7 {
                let date = calendar.date(byAdding: .day, value: week * 7 + day, to: startMonday)!
                if date <= today {
                    column.append(date)
                } else {
                    column.append(nil)
                }
            }
            grid.append(column)
        }
        return grid
    }

    private func cellColor(count: Int, maxCount: Int) -> Color {
        if count == 0 {
            return Color(.systemGray5)
        }
        let level: Int
        if maxCount <= 4 {
            level = count
        } else {
            let step = Double(maxCount) / 4.0
            level = min(4, Int(ceil(Double(count) / step)))
        }
        return levelColor(level)
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0: Color(.systemGray5)
        case 1: Color.green.opacity(0.3)
        case 2: Color.green.opacity(0.5)
        case 3: Color.green.opacity(0.7)
        case 4: Color.green.opacity(0.9)
        default: Color.green
        }
    }

    private func isFirstWeekOfMonth(date: Date, weekIndex: Int, grid: [[Date?]]) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        if weekIndex == 0 { return true }
        guard let prevDate = grid[weekIndex - 1][0] else { return true }
        return calendar.component(.month, from: prevDate) != month
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月"
        return formatter.string(from: date)
    }
}

// MARK: - Day Activity Sheet

private struct DayActivitySheet: View {
    let date: Date
    var viewModel: MangaViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("browserMode") private var browserMode: String = "external"
    @State private var safariURL: URL?

    var body: some View {
        NavigationStack {
            List {
                let activities = viewModel.fetchActivities(for: date)
                ForEach(activities, id: \.id) { activity in
                    let entry = viewModel.findEntry(by: activity.mangaEntryID)
                    Button {
                        if let entry {
                            openMangaURL(entry.url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let entry, let imageData = entry.imageData,
                               let image = imageData.toSwiftUIImage() {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.fill.tertiary)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "book.closed")
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            Text(activity.mangaName)
                                .foregroundStyle(.primary)
                        }
                    }
                    .tint(.primary)
                    .disabled(entry == nil)
                }
            }
            .navigationTitle(dateTitle)
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
            }
            #endif
        }
        .presentationDetents([.medium])
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

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
}

// MARK: - Date + Identifiable

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
