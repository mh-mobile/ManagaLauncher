import AppIntents
import WidgetKit

struct ChangeDayIntent: AppIntent {
    static var title: LocalizedStringResource = "曜日を変更"
    static var isDiscoverable = false

    @Parameter(title: "Direction")
    var direction: Int // -1 = prev, 1 = next, 0 = reset to today

    init() {
        self.direction = 0
    }

    init(direction: Int) {
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        let current = WidgetDayStore.shared.currentDay
        if direction == 0 {
            WidgetDayStore.shared.currentDay = DayOfWeek.today
        } else {
            let newRaw = (current.rawValue + direction + 7) % 7
            WidgetDayStore.shared.currentDay = DayOfWeek(rawValue: newRaw) ?? .sunday
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

final class WidgetDayStore {
    static let shared = WidgetDayStore()

    private let key = "widget_selected_day"
    private let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)

    var currentDay: DayOfWeek {
        get {
            guard let defaults,
                  let raw = defaults.object(forKey: key) as? Int,
                  let day = DayOfWeek(rawValue: raw) else {
                return DayOfWeek.today
            }
            // Check if stored date is stale (from a different day)
            let storedDate = defaults.object(forKey: "widget_selected_date") as? Date ?? .distantPast
            if !Calendar.current.isDateInToday(storedDate) {
                return DayOfWeek.today
            }
            return day
        }
        set {
            defaults?.set(newValue.rawValue, forKey: key)
            defaults?.set(Date(), forKey: "widget_selected_date")
        }
    }
}
