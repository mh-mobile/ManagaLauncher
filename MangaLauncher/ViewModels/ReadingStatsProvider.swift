import Foundation
import SwiftData

struct ReadingStatsProvider {
    let modelContext: ModelContext

    func fetchActivityCounts(days: Int = 84) -> [Date: Int] {
        guard let baseDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return [:]
        }
        let startDate = Calendar.current.startOfDay(for: baseDate)
        let descriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.date >= startDate },
            sortBy: [SortDescriptor(\.date)]
        )
        let activities = modelContext.fetchLogged(descriptor)
        var counts: [Date: Int] = [:]
        for activity in activities {
            counts[activity.date, default: 0] += 1
        }
        return counts
    }

    func fetchActivities(for date: Date) -> [ReadingActivity] {
        let targetDate = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.date == targetDate },
            sortBy: [SortDescriptor(\.date)]
        )
        return modelContext.fetchLogged(descriptor)
    }

    /// 年間の streak（現在・最長）と最もアクティブな曜日をまとめて計算する。
    /// 個別に呼ぶと365日分のフェッチが毎回走るため、一度にまとめて取得する。
    struct YearlyStats {
        let currentStreak: Int
        let longestStreak: Int
        let mostActiveDay: String?
    }

    func yearlyStats() -> YearlyStats {
        let counts = fetchActivityCounts(days: 365)
        return YearlyStats(
            currentStreak: Self.computeCurrentStreak(from: counts),
            longestStreak: Self.computeLongestStreak(from: counts),
            mostActiveDay: Self.computeMostActiveDay(from: counts)
        )
    }

    func currentStreak() -> Int {
        Self.computeCurrentStreak(from: fetchActivityCounts(days: 365))
    }

    func longestStreak() -> Int {
        Self.computeLongestStreak(from: fetchActivityCounts(days: 365))
    }

    func totalReadCount() -> Int {
        let descriptor = FetchDescriptor<ReadingActivity>()
        return modelContext.fetchCountLogged(descriptor)
    }

    func thisWeekReadCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return 0
        }
        let descriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.date >= monday }
        )
        return modelContext.fetchCountLogged(descriptor)
    }

    func mostActiveDay() -> String? {
        Self.computeMostActiveDay(from: fetchActivityCounts(days: 365))
    }

    // MARK: - Pure Computation Helpers

    private static func computeCurrentStreak(from counts: [Date: Int]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        if counts[checkDate] == nil {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = prev
        }

        while counts[checkDate] != nil {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    private static func computeLongestStreak(from counts: [Date: Int]) -> Int {
        let sortedDates = counts.keys.sorted()
        guard !sortedDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            if calendar.date(byAdding: .day, value: 1, to: sortedDates[i - 1]) == sortedDates[i] {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private static func computeMostActiveDay(from counts: [Date: Int]) -> String? {
        guard !counts.isEmpty else { return nil }
        let calendar = Calendar.current
        var weekdayCounts: [Int: Int] = [:]
        for (date, count) in counts {
            let weekday = calendar.component(.weekday, from: date)
            weekdayCounts[weekday, default: 0] += count
        }
        guard let best = weekdayCounts.max(by: { $0.value < $1.value }),
              let day = DayOfWeek(rawValue: best.key - 1) else { return nil }
        return day.shortName
    }
}
