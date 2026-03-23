import Foundation
import UserNotifications

enum NotificationManager {
    private static let enabledKey = "notificationEnabled"
    private static let hourKey = "notificationHour"
    private static let minuteKey = "notificationMinute"
    private static let identifierPrefix = "manga_reminder_"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var notificationHour: Int {
        get {
            let val = UserDefaults.standard.object(forKey: hourKey) as? Int
            return val ?? 9
        }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    static var notificationMinute: Int {
        get {
            let val = UserDefaults.standard.object(forKey: minuteKey) as? Int
            return val ?? 0
        }
        set { UserDefaults.standard.set(newValue, forKey: minuteKey) }
    }

    static var notificationTime: DateComponents {
        var components = DateComponents()
        components.hour = notificationHour
        components.minute = notificationMinute
        return components
    }

    static func requestPermissionAndEnable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                isEnabled = true
                // Also enable badge since we now have permission
                BadgeManager.isEnabled = true
            }
            return granted
        } catch {
            return false
        }
    }

    static func scheduleNotifications(entryCounts: [DayOfWeek: Int]) {
        let center = UNUserNotificationCenter.current()

        // Remove existing reminders
        let identifiers = DayOfWeek.allCases.map { "\(identifierPrefix)\($0.rawValue)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard isEnabled else { return }

        for day in DayOfWeek.allCases {
            let count = entryCounts[day] ?? 0
            guard count > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "マンガ曜日"
            content.body = "\(day.displayName)のマンガをチェックしましょう"
            content.sound = .default

            var dateComponents = notificationTime
            // Calendar.weekday: 1=Sunday, 2=Monday, ...
            dateComponents.weekday = day.rawValue + 1

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(day.rawValue)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        let identifiers = DayOfWeek.allCases.map { "\(identifierPrefix)\($0.rawValue)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
