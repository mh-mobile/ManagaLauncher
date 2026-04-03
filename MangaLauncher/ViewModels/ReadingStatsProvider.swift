import Foundation
import SwiftData

struct ReadingStatsProvider {
    let modelContext: ModelContext

    func fetchActivityCounts(days: Int = 84) -> [Date: Int] {
        let startDate = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        )
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

    func currentStreak() -> Int {
        let counts = fetchActivityCounts(days: 365)
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        if counts[checkDate] == nil {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        while counts[checkDate] != nil {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    func longestStreak() -> Int {
        let counts = fetchActivityCounts(days: 365)
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

    func totalReadCount() -> Int {
        let descriptor = FetchDescriptor<ReadingActivity>()
        return modelContext.fetchCountLogged(descriptor)
    }

    func thisWeekReadCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let descriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.date >= monday }
        )
        return modelContext.fetchCountLogged(descriptor)
    }

    func mostActiveDay() -> String? {
        let counts = fetchActivityCounts(days: 365)
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
