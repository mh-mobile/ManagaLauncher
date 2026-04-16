import Foundation

/// アプリ全体で使う UserDefaults / AppStorage キーの一元定義。
/// 文字列リテラルの散在を防ぎ、タイポ検出を型システムに任せる。
enum UserDefaultsKeys {
    // MARK: - Achievement / streak
    static let lastStreakShownDate = "lastStreakShownDate"
    static let shownMilestones = "shownMilestones"

    // MARK: - Onboarding
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let hasSeenCatchUpTutorial = "hasSeenCatchUpTutorial"

    // MARK: - Display
    static let displayMode = "displayMode"
    static let browserMode = "browserMode"
    static let showsNextUpdateBadge = "showsNextUpdateBadge"

    // MARK: - Pending intent signals (App Group 経由)
    static let pendingIntentData = "pendingIntentData"
    static let pendingOpenDay = "pendingOpenDay"
    static let pendingOpenCatchUp = "pendingOpenCatchUp"
    static let pendingIntentImage = "pendingIntentImage.jpg" // App Group 内ファイル名
}

/// Notification.Name もここで集約する。MangaLauncherApp と widget extension
/// 両方から共通で参照される。
extension Notification.Name {
    /// 曜日タブの切替リクエスト。object に DayOfWeek.rawValue (Int) を渡す。
    static let switchToDay = Notification.Name("switchToDay")
    /// キャッチアップ画面の起動リクエスト。
    static let openCatchUp = Notification.Name("openCatchUp")
}
