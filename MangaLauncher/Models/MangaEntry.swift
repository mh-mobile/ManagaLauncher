import Foundation
import SwiftData

enum DayOfWeek: Int, Codable, CaseIterable, Identifiable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday, hiatus, completed

    var id: Int { rawValue }

    var isHiatus: Bool { self == .hiatus }
    var isCompleted: Bool { self == .completed }

    var shortName: String {
        switch self {
        case .sunday: "日"
        case .monday: "月"
        case .tuesday: "火"
        case .wednesday: "水"
        case .thursday: "木"
        case .friday: "金"
        case .saturday: "土"
        case .hiatus: "休"
        case .completed: "完"
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
        case .hiatus: "休載中"
        case .completed: "完結"
        }
    }

    /// Display order: completed first, then weekdays, hiatus last
    static var orderedCases: [DayOfWeek] {
        [.completed, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday, .hiatus]
    }

    /// Days only (excludes hiatus)
    static var orderedDays: [DayOfWeek] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    static var today: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar.weekday: 1=Sunday, 2=Monday, ...
        return DayOfWeek(rawValue: weekday - 1) ?? .sunday
    }
}

enum MangaType: Int, Codable, CaseIterable {
    case serial = 0
    case oneShot = 1

    var displayName: String {
        switch self {
        case .serial: "連載"
        case .oneShot: "読み切り"
        }
    }
}

enum PublicationStatus: Int, Codable, CaseIterable {
    case active = 0
    case hiatus = 1
    case completed = 2

    var displayName: String {
        switch self {
        case .active: "連載中"
        case .hiatus: "休載中"
        case .completed: "完結"
        }
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
    var updateIntervalWeeks: Int = 1
    var nextExpectedUpdate: Date?
    var isOnHiatus: Bool = false
    var isCompleted: Bool = false
    var isOneShot: Bool = false

    @Transient
    var mangaType: MangaType {
        get { isOneShot ? .oneShot : .serial }
        set {
            isOneShot = newValue == .oneShot
            if isOneShot {
                isOnHiatus = false
                isCompleted = false
            }
        }
    }

    @Transient
    var publicationStatus: PublicationStatus {
        get {
            if isCompleted { return .completed }
            if isOnHiatus { return .hiatus }
            return .active
        }
        set {
            isOnHiatus = newValue == .hiatus
            isCompleted = newValue == .completed
        }
    }

    @Transient
    var cachedImageAspectRatio: CGFloat?

    @Transient
    var dayOfWeek: DayOfWeek {
        get { DayOfWeek(rawValue: dayOfWeekRawValue) ?? .sunday }
        set { dayOfWeekRawValue = newValue.rawValue }
    }

    @Transient
    var isRead: Bool {
        if isOnHiatus || isCompleted { return true }
        if isOneShot && lastReadDate != nil { return true }
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
        let mostRecent = Self.mostRecentOccurrence(of: dayOfWeek)
        nextExpectedUpdate = Calendar.current.date(byAdding: .day, value: updateIntervalWeeks * 7, to: mostRecent)
    }

    func resetNextUpdate() {
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
