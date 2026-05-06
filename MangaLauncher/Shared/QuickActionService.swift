import UIKit

/// ホーム画面アイコン長押し時のクイックアクション (UIApplicationShortcutItem) を管理する。
/// アクション実行時は既存の NotificationCenter パターンで各画面に伝達する。
enum QuickActionService {

    // MARK: - Action Types

    enum ActionType: String, CaseIterable {
        case openToday = "com.mangalauncher.openToday"
        case catchUp   = "com.mangalauncher.catchUp"
        case addEntry  = "com.mangalauncher.addEntry"
        case search    = "com.mangalauncher.search"
    }

    // MARK: - Pending (Cold Start)

    /// コールドスタート時はまだ View ツリーが構築されていないため、
    /// shortcutItem を保持して scenePhase == .active 後に処理する。
    private(set) static var pendingShortcutType: String?

    static func savePending(_ shortcutItem: UIApplicationShortcutItem) {
        pendingShortcutType = shortcutItem.type
    }

    /// 保留中のクイックアクションがあれば処理して消化する。
    static func handlePendingIfNeeded() {
        guard let type = pendingShortcutType else { return }
        pendingShortcutType = nil
        let item = UIApplicationShortcutItem(type: type, localizedTitle: "")
        handle(item)
    }

    // MARK: - Register Dynamic Shortcuts

    /// 動的ショートカットを登録する。active / background 遷移時に呼び出す。
    static func updateShortcutItems(unreadCount: Int) {
        let items: [UIApplicationShortcutItem] = [
            UIApplicationShortcutItem(
                type: ActionType.openToday.rawValue,
                localizedTitle: "今日のマンガ",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "book.fill")
            ),
            UIApplicationShortcutItem(
                type: ActionType.catchUp.rawValue,
                localizedTitle: "キャッチアップ",
                localizedSubtitle: unreadCount > 0 ? "未読 \(unreadCount) 件" : nil,
                icon: UIApplicationShortcutIcon(systemImageName: "bolt.fill")
            ),
            UIApplicationShortcutItem(
                type: ActionType.addEntry.rawValue,
                localizedTitle: "作品を追加",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus")
            ),
            UIApplicationShortcutItem(
                type: ActionType.search.rawValue,
                localizedTitle: "検索",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass")
            ),
        ]
        UIApplication.shared.shortcutItems = items
    }

    // MARK: - Handle Action

    /// クイックアクションを処理し、対応する通知を post する。
    static func handle(_ shortcutItem: UIApplicationShortcutItem) {
        guard let actionType = ActionType(rawValue: shortcutItem.type) else { return }

        switch actionType {
        case .openToday:
            NotificationCenter.default.post(name: .switchToDay, object: DayOfWeek.today.rawValue)

        case .catchUp:
            let todayRaw = DayOfWeek.today.rawValue
            NotificationCenter.default.post(name: .switchToDay, object: todayRaw)
            NotificationCenter.default.post(name: .openCatchUp, object: nil)

        case .addEntry:
            NotificationCenter.default.post(name: .switchToDay, object: DayOfWeek.today.rawValue)
            NotificationCenter.default.post(name: .openAddSheet, object: nil)

        case .search:
            NotificationCenter.default.post(name: .switchToSearch, object: nil)
        }
    }
}
