import Foundation
import UserNotifications

public enum NotificationManager {
    private static let enabledKey = "notificationEnabled"
    private static let hourKey = "notificationHour"
    private static let minuteKey = "notificationMinute"
    private static let identifierPrefix = "manga_reminder_"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    public static var notificationHour: Int {
        get {
            let val = UserDefaults.standard.object(forKey: hourKey) as? Int
            return val ?? 9
        }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    public static var notificationMinute: Int {
        get {
            let val = UserDefaults.standard.object(forKey: minuteKey) as? Int
            return val ?? 0
        }
        set { UserDefaults.standard.set(newValue, forKey: minuteKey) }
    }

    public static var notificationTime: DateComponents {
        var components = DateComponents()
        components.hour = notificationHour
        components.minute = notificationMinute
        return components
    }

    public static func requestPermissionAndEnable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                isEnabled = true
                BadgeManager.isEnabled = true
            }
            return granted
        } catch {
            return false
        }
    }

    /// Schedule weekly notifications for days that have entries.
    /// - Parameter entryCounts: Dictionary mapping day rawValue (0=Sunday..6=Saturday) to entry count.
    /// - Parameter dayDisplayNames: Dictionary mapping day rawValue to display name (e.g. "月曜日").
    public static func scheduleNotifications(entryCounts: [Int: Int], dayDisplayNames: [Int: String]) {
        let center = UNUserNotificationCenter.current()

        let allDayRawValues = Array(0...7)
        let identifiers = allDayRawValues.map { "\(identifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard isEnabled else { return }

        for (dayRawValue, count) in entryCounts {
            guard count > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "マンガ曜日"
            let displayName = dayDisplayNames[dayRawValue] ?? ""
            content.body = "\(displayName)のマンガをチェックしましょう"
            content.sound = .default

            var dateComponents = notificationTime
            // Calendar.weekday: 1=Sunday, 2=Monday, ...
            dateComponents.weekday = dayRawValue + 1

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(dayRawValue)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    public static func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        let allDayRawValues = Array(0...7)
        let identifiers = allDayRawValues.map { "\(identifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
