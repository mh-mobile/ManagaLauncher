import Foundation

/// アプリ全体で使う UserDefaults / AppStorage キーおよび定数の一元定義。
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
    static let showHiddenSection = "showHiddenSection"
    static let appIconMode = "appIconMode"
    static let recentActivityExpanded = "recentActivityExpanded"

    // MARK: - Pending intent signals (App Group 経由)
    static let pendingIntentData = "pendingIntentData"
    static let pendingOpenDay = "pendingOpenDay"
    static let pendingOpenCatchUp = "pendingOpenCatchUp"
    static let pendingIntentImage = "pendingIntentImage.jpg" // App Group 内ファイル名
}

/// アプリ全体で使う URL 定数の一元定義。
/// リテラルの散在を防ぎ、変更時の影響範囲を限定する。
enum AppConstants {
    /// App Store のアプリページ URL。
    static let appStoreURL = URL(string: "https://apps.apple.com/jp/app/%E3%83%9E%E3%83%B3%E3%82%AC%E6%9B%9C%E6%97%A5/id6760709060")!
    /// iTunes Search API のバージョン確認エンドポイント。
    static let itunesLookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=com.mh-mobile.MangaYoubi&country=jp")!
}

/// Notification.Name もここで集約する。MangaLauncherApp と widget extension
/// 両方から共通で参照される。
extension Notification.Name {
    /// 曜日タブの切替リクエスト。object に DayOfWeek.rawValue (Int) を渡す。
    static let switchToDay = Notification.Name("switchToDay")
    /// キャッチアップ画面の起動リクエスト。
    static let openCatchUp = Notification.Name("openCatchUp")
    /// ホームタブの新規登録シート表示リクエスト。
    static let openAddSheet = Notification.Name("openAddSheet")
    /// 検索タブへの切替リクエスト。
    static let switchToSearch = Notification.Name("switchToSearch")
}
