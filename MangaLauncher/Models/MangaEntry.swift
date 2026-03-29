import Foundation
import SwiftData

enum DayOfWeek: Int, Codable, CaseIterable, Identifiable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: "日"
        case .monday: "月"
        case .tuesday: "火"
        case .wednesday: "水"
        case .thursday: "木"
        case .friday: "金"
        case .saturday: "土"
        }
    }

    var displayName: String {
        switch self {
        case .sunday: "日曜日"
        case .monday: "月曜日"
        case .tuesday: "火曜日"
        case .wednesday: "水曜日"
        case .thursday: "木曜日"
        case .friday: "金曜日"
        case .saturday: "土曜日"
        }
    }

    var next: DayOfWeek {
        DayOfWeek(rawValue: (rawValue + 1) % 7)!
    }

    var previous: DayOfWeek {
        DayOfWeek(rawValue: (rawValue + 6) % 7)!
    }

    /// Monday-start order for display
    static var orderedCases: [DayOfWeek] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    static var today: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar.weekday: 1=Sunday, 2=Monday, ...
        return DayOfWeek(rawValue: weekday - 1) ?? .sunday
    }
}

@Model
final class MangaEntry {
    var id: UUID = UUID()
    var name: String = ""
    var url: String = ""
    var dayOfWeekRawValue: Int = 1
    var sortOrder: Int = 0
    var iconColor: String = "blue"
    var publisher: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var lastReadDate: Date?
    @Transient var updateIntervalWeeks: Int = 1
    @Transient var nextExpectedUpdate: Date?

    @Transient
    var dayOfWeek: DayOfWeek {
        get { DayOfWeek(rawValue: dayOfWeekRawValue) ?? .sunday }
        set { dayOfWeekRawValue = newValue.rawValue }
    }

    @Transient
    var isRead: Bool {
        guard let lastReadDate else { return false }
        // If next expected update is in the future, stay read
        if let nextUpdate = nextExpectedUpdate, nextUpdate > Date.now {
            return true
        }
        let mostRecentDay = Self.mostRecentOccurrence(of: dayOfWeek)
        return lastReadDate >= mostRecentDay
    }

    static func mostRecentOccurrence(of day: DayOfWeek, from date: Date = .now) -> Date {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: date) - 1 // 0=Sun
        let targetWeekday = day.rawValue
        let daysBack = (todayWeekday - targetWeekday + 7) % 7
        return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysBack, to: date)!)
    }

    func advanceToNextUpdate() {
        guard updateIntervalWeeks > 1 else {
            nextExpectedUpdate = nil
            return
        }
        let mostRecent = Self.mostRecentOccurrence(of: dayOfWeek)
        nextExpectedUpdate = Calendar.current.date(byAdding: .day, value: updateIntervalWeeks * 7, to: mostRecent)
    }

    func resetNextUpdate() {
        guard updateIntervalWeeks > 1 else {
            nextExpectedUpdate = nil
            return
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) - 1
        let target = dayOfWeek.rawValue
        let daysAhead = (target - todayWeekday + 7) % 7
        let nextDay = daysAhead == 0 ? today : calendar.date(byAdding: .day, value: daysAhead, to: today)!
        nextExpectedUpdate = nextDay
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        url: String = "",
        dayOfWeek: DayOfWeek = .monday,
        sortOrder: Int = 0,
        iconColor: String = "blue",
        publisher: String = "",
        imageData: Data? = nil,
        updateIntervalWeeks: Int = 1
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.dayOfWeekRawValue = dayOfWeek.rawValue
        self.sortOrder = sortOrder
        self.iconColor = iconColor
        self.publisher = publisher
        self.imageData = imageData
        self.updateIntervalWeeks = updateIntervalWeeks
    }
}
