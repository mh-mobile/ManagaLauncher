import Foundation
import UserNotifications

public enum BadgeManager {
    private static let enabledKey = "badgeEnabled"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    public static func requestPermissionAndEnable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.badge])
            if granted {
                isEnabled = true
            }
            return granted
        } catch {
            return false
        }
    }

    public static func updateBadge(unreadCount: Int) {
        guard isEnabled else {
            clearBadge()
            return
        }
        let center = UNUserNotificationCenter.current()
        center.setBadgeCount(unreadCount)
    }

    public static func clearBadge() {
        let center = UNUserNotificationCenter.current()
        center.setBadgeCount(0)
    }
}
