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

    @Transient
    var dayOfWeek: DayOfWeek {
        get { DayOfWeek(rawValue: dayOfWeekRawValue) ?? .sunday }
        set { dayOfWeekRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        url: String = "",
        dayOfWeek: DayOfWeek = .monday,
        sortOrder: Int = 0,
        iconColor: String = "blue",
        publisher: String = "",
        imageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.dayOfWeekRawValue = dayOfWeek.rawValue
        self.sortOrder = sortOrder
        self.iconColor = iconColor
        self.publisher = publisher
        self.imageData = imageData
    }
}
