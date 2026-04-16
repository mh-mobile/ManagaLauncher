import AppIntents
import Foundation

// Notification.Name の共有定義は UserDefaultsKeys.swift に集約

// MARK: - Shared App Enums

enum DayOfWeekAppEnum: String, AppEnum {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "曜日"
    }

    static var caseDisplayRepresentations: [DayOfWeekAppEnum: DisplayRepresentation] {
        [
            .sunday: "日曜日",
            .monday: "月曜日",
            .tuesday: "火曜日",
            .wednesday: "水曜日",
            .thursday: "木曜日",
            .friday: "金曜日",
            .saturday: "土曜日",
        ]
    }

    var toDayOfWeek: DayOfWeek {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}

// MARK: - Shared Intents

/// Siri / Shortcuts から曜日タブを開く intent。MangaShortcuts provider で登録される。
/// ControlWidget (ContextCenter) からも同じ型を利用する。
struct OpenDayIntent: AppIntent {
    static var title: LocalizedStringResource = "曜日を開く"
    static var description: IntentDescription = "マンガ曜日で指定した曜日のタブを開きます"
    static var openAppWhenRun = true

    @Parameter(title: "曜日")
    var dayOfWeek: DayOfWeekAppEnum

    init() {
        self.dayOfWeek = .monday
    }

    init(dayOfWeek: DayOfWeekAppEnum) {
        self.dayOfWeek = dayOfWeek
    }

    func perform() async throws -> some IntentResult {
        let rawValue = dayOfWeek.toDayOfWeek.rawValue
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        defaults?.set(rawValue, forKey: UserDefaultsKeys.pendingOpenDay)
        await MainActor.run {
            NotificationCenter.default.post(name: .switchToDay, object: rawValue)
        }
        return .result()
    }
}

/// コントロールセンター: 今日のマンガを開く。
/// 実行時に DayOfWeek.today を解決するので、コントロール追加日時点で固定化されない。
struct OpenTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "今日のマンガを開く"
    static var description: IntentDescription = "マンガ曜日で今日の曜日のタブを開きます"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let raw = DayOfWeek.today.rawValue
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        defaults?.set(raw, forKey: UserDefaultsKeys.pendingOpenDay)
        await MainActor.run {
            NotificationCenter.default.post(name: .switchToDay, object: raw)
        }
        return .result()
    }
}

/// コントロールセンター: 今日のキャッチアップを開始。
/// 現在の曜日タブに依存せず、常に「今日」のキャッチアップを起動する。
struct OpenCatchUpIntent: AppIntent {
    static var title: LocalizedStringResource = "今日のキャッチアップを開始"
    static var description: IntentDescription = "今日の未読マンガをキャッチアップ画面で開きます"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let todayRaw = DayOfWeek.today.rawValue
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        defaults?.set(todayRaw, forKey: UserDefaultsKeys.pendingOpenDay)
        defaults?.set(true, forKey: UserDefaultsKeys.pendingOpenCatchUp)
        await MainActor.run {
            // 曜日を今日に切り替えてからキャッチアップを立ち上げる（順序重要）
            NotificationCenter.default.post(name: .switchToDay, object: todayRaw)
            NotificationCenter.default.post(name: .openCatchUp, object: nil)
        }
        return .result()
    }
}

extension DayOfWeek {
    /// AppIntents 層で使う DayOfWeekAppEnum への変換
    var appEnum: DayOfWeekAppEnum {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}

/// ホームウィジェットから「指定曜日のキャッチアップ」を起動する intent。
/// 曜日切替 + キャッチアップ起動をまとめて行う。
struct OpenCatchUpForDayIntent: AppIntent {
    static var title: LocalizedStringResource = "指定曜日のキャッチアップを開く"
    static var isDiscoverable = false
    static var openAppWhenRun = true

    @Parameter(title: "曜日")
    var dayOfWeek: DayOfWeekAppEnum

    init() {
        self.dayOfWeek = .monday
    }

    init(dayOfWeek: DayOfWeekAppEnum) {
        self.dayOfWeek = dayOfWeek
    }

    func perform() async throws -> some IntentResult {
        let raw = dayOfWeek.toDayOfWeek.rawValue
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        defaults?.set(raw, forKey: UserDefaultsKeys.pendingOpenDay)
        defaults?.set(true, forKey: UserDefaultsKeys.pendingOpenCatchUp)
        await MainActor.run {
            // 先に曜日を切り替えてから CatchUp を立ち上げる（順序重要）
            NotificationCenter.default.post(name: .switchToDay, object: raw)
            NotificationCenter.default.post(name: .openCatchUp, object: nil)
        }
        return .result()
    }
}

/// コントロール追加時の曜日選択用。選択した曜日を ControlWidget 側で保持する。
struct DayConfigurationIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "曜日を選択"

    /// ControlConfigurationIntent はパラメータの Optional を要求する。
    /// 未設定時は MangaDayControl 側で .monday などにフォールバックする。
    @Parameter(title: "曜日")
    var dayOfWeek: DayOfWeekAppEnum?

    init() {}
}
