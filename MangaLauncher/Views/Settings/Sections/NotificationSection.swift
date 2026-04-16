import SwiftUI
import NotificationKit

/// 設定画面の「通知」セクション。未読バッジ / 更新通知 / 通知時刻を管理する。
struct NotificationSection: View {
    var viewModel: MangaViewModel

    @State private var badgeEnabled = BadgeManager.isEnabled
    @State private var notificationEnabled = NotificationManager.isEnabled
    @State private var notificationTime: Date = {
        var components = DateComponents()
        components.hour = NotificationManager.notificationHour
        components.minute = NotificationManager.notificationMinute
        return Calendar.current.date(from: components) ?? Date()
    }()

    var body: some View {
        Section {
            Toggle("未読バッジ", isOn: $badgeEnabled)
                .onChange(of: badgeEnabled) { _, newValue in
                    handleBadgeToggle(enabled: newValue)
                }
            Toggle("更新通知", isOn: $notificationEnabled)
                .onChange(of: notificationEnabled) { _, newValue in
                    handleNotificationToggle(enabled: newValue)
                }
            if notificationEnabled {
                DatePicker("通知時間", selection: $notificationTime, displayedComponents: .hourAndMinute)
                    .onChange(of: notificationTime) { _, newValue in
                        applyNotificationTime(newValue)
                    }
            }
        } header: {
            Text("通知")
        } footer: {
            Text("未読バッジはアプリアイコンに未読数を表示します。更新通知は登録がある曜日の指定時間にリマインドします。")
        }
    }

    private func handleBadgeToggle(enabled: Bool) {
        if enabled {
            Task {
                let granted = await BadgeManager.requestPermissionAndEnable()
                if !granted {
                    badgeEnabled = false
                } else {
                    let count = viewModel.unreadCount(for: .today)
                    BadgeManager.updateBadge(unreadCount: count)
                }
            }
        } else {
            BadgeManager.isEnabled = false
            BadgeManager.clearBadge()
        }
    }

    private func handleNotificationToggle(enabled: Bool) {
        if enabled {
            Task {
                let granted = await NotificationManager.requestPermissionAndEnable()
                if !granted {
                    notificationEnabled = false
                } else {
                    viewModel.rescheduleNotifications()
                }
            }
        } else {
            NotificationManager.isEnabled = false
            NotificationManager.cancelAllNotifications()
        }
    }

    private func applyNotificationTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        NotificationManager.notificationHour = components.hour ?? 9
        NotificationManager.notificationMinute = components.minute ?? 0
        viewModel.rescheduleNotifications()
    }
}
