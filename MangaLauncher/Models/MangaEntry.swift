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

    /// Days only (Mon → Sun ordering for tabs)
    static var orderedDays: [DayOfWeek] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    static var today: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar.weekday: 1=Sunday, 2=Monday, ...
        return DayOfWeek(rawValue: weekday - 1) ?? .sunday
    }
}

enum MangaType: Int, Codable, CaseIterable {
    case serial = 0
    case oneShot = 1

    var displayName: String {
        switch self {
        case .serial: "連載"
        case .oneShot: "読み切り"
        }
    }
}

/// 作品の掲載状況（出版社・作者側の状態）
enum PublicationStatus: Int, Codable, CaseIterable, Identifiable {
    case active = 0      // 連載中
    case hiatus = 1      // 休載中
    case finished = 2    // 完結

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .active: "連載中"
        case .hiatus: "休載中"
        case .finished: "完結"
        }
    }
}

/// 読者の読書状況（ユーザー側の進捗）
enum ReadingState: Int, Codable, CaseIterable, Identifiable {
    case following = 0   // 連載追っかけ中
    case backlog = 1     // 積読中
    case archived = 2    // 読了（アーカイブ）

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .following: "追っかけ中"
        case .backlog: "積読"
        case .archived: "読了"
        }
    }
}

/// 状態の invariants:
/// - `isOneShot == true` のとき `publicationStatus == .active` かつ `readingState != .backlog`
///   （読み切りは掲載状況の概念がなく、積読とも不整合。`.following` か `.archived` のみ）
/// - `readingState == .archived` のとき `isRead` は常に true
/// これらは `MangaViewModel.addEntry` / `updateEntry` / `MangaEntry.normalizeOneShotInvariants()` で強制される。
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
    var lastReadDate: Date?
    var updateIntervalWeeks: Int = 1
    var nextExpectedUpdate: Date?
    var isOneShot: Bool = false
    /// 1作品に1つの長文メモ
    var memo: String = ""
    /// メモの最終更新日時。並び替え用。
    var memoUpdatedAt: Date?
    /// 現在の話数。nil は未設定。
    var currentEpisode: Int?
    /// 表示用ラベル（「おまけ」「1.5話」等）。nil なら currentEpisode から自動生成。
    var episodeLabel: String?
    /// 非表示フラグ（シークレットモード）
    var isHidden: Bool = false
    /// ソフトデリート日時（nil = 未削除）
    var deletedAt: Date?
    /// フォーカス積読フラグ。最大3本まで同時にフォーカス可能。
    var isFocused: Bool = false
    /// フォーカス指定日時。フォーカス中積読セクションの並び順（降順 = 新しいフォーカスが先頭）に使う。
    var focusedAt: Date?

    /// 掲載状況の Int 値（PublicationStatus.rawValue）
    var publicationStatusRawValue: Int = 0
    /// 読書状況の Int 値（ReadingState.rawValue）
    var readingStateRawValue: Int = 0
    /// マイグレーションバージョン（0=未移行、1=新モデル）
    var stateMigrationVersion: Int = 0

    // MARK: - Legacy fields (kept for backward-compat / one-time migration only)
    var isOnHiatus: Bool = false
    var isCompleted: Bool = false
    var isBacklog: Bool = false

    @Transient
    var mangaType: MangaType {
        get { isOneShot ? .oneShot : .serial }
        set {
            isOneShot = newValue == .oneShot
            normalizeOneShotInvariants()
        }
    }

    /// 読み切りのときに不整合な状態 (hiatus/finished、backlog) を矯正する。
    /// ViewModel / mangaType setter から共通に呼ばれる。
    func normalizeOneShotInvariants() {
        guard isOneShot else { return }
        if publicationStatusRawValue != PublicationStatus.active.rawValue {
            publicationStatusRawValue = PublicationStatus.active.rawValue
        }
        if readingStateRawValue == ReadingState.backlog.rawValue {
            readingStateRawValue = ReadingState.following.rawValue
        }
    }

    @Transient
    var publicationStatus: PublicationStatus {
        get { PublicationStatus(rawValue: publicationStatusRawValue) ?? .active }
        set { publicationStatusRawValue = newValue.rawValue }
    }

    @Transient
    var readingState: ReadingState {
        get { ReadingState(rawValue: readingStateRawValue) ?? .following }
        set { readingStateRawValue = newValue.rawValue }
    }

    @Transient
    var cachedImageAspectRatio: CGFloat?

    @Transient
    var dayOfWeek: DayOfWeek {
        get { DayOfWeek(rawValue: dayOfWeekRawValue) ?? .sunday }
        set { dayOfWeekRawValue = newValue.rawValue }
    }

    /// 既読扱いか否か（カレンダーベースの未読サイクル含む）
    @Transient
    var isRead: Bool {
        // 読了アーカイブ: 常に既読
        if readingState == .archived { return true }
        // 掲載休載中: 次の更新まで既読据え置き
        if publicationStatus == .hiatus { return true }
        // 掲載完結: 一度読んだら既読のまま戻らない
        if publicationStatus == .finished {
            return lastReadDate != nil
        }
        // 読み切り: 1度読んだら既読
        if isOneShot { return lastReadDate != nil }
        // 積読: 今日読んだら既読、翌日リセット
        if readingState == .backlog {
            guard let lastReadDate else { return false }
            return Calendar.current.isDateInToday(lastReadDate)
        }
        // 通常: 曜日サイクル
        guard let lastReadDate else { return false }
        if let nextUpdate = nextExpectedUpdate, nextUpdate > Date.now {
            return true
        }
        let mostRecentDay = Self.mostRecentOccurrence(of: dayOfWeek)
        return lastReadDate >= mostRecentDay
    }

    static func mostRecentOccurrence(of day: DayOfWeek, from date: Date = .now) -> Date {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: date) - 1 // 0=Sun
        let targetWeekday = day.rawValue
        let daysBack = (todayWeekday - targetWeekday + 7) % 7
        let adjustedDate = calendar.date(byAdding: .day, value: -daysBack, to: date) ?? date
        return calendar.startOfDay(for: adjustedDate)
    }

    func advanceToNextUpdate() {
        let mostRecent = Self.mostRecentOccurrence(of: dayOfWeek)
        nextExpectedUpdate = Calendar.current.date(byAdding: .day, value: updateIntervalWeeks * 7, to: mostRecent)
    }

    func resetNextUpdate() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) - 1
        let target = dayOfWeek.rawValue
        let daysAhead = (target - todayWeekday + 7) % 7
        let nextDay = daysAhead == 0 ? today : (calendar.date(byAdding: .day, value: daysAhead, to: today) ?? today)
        nextExpectedUpdate = nextDay
    }

    /// 旧 Bool フィールド（isOnHiatus / isCompleted / isBacklog）から
    /// 新しい publicationStatus / readingState へ移行する。
    /// 一度移行されると stateMigrationVersion=1 になり再実行されない。
    ///
    /// 重要: 別端末ですでに移行済みのレコードが CloudKit 経由で同期されてきた場合、
    /// 受信側 (例: Vision Pro 初回起動) では legacy フィールドが false (デフォルト)
    /// で stateMigrationVersion = 0 になっていることがある。その状態で
    /// `else` 分岐の「全部 default にする」ロジックを実行すると、cloud から
    /// 来た正しい publicationStatus / readingState を上書きしてしまう。
    /// → legacy が完全 false かつ新フィールドが既に non-default なら、
    ///   write を一切行わず version だけ進める。
    func migrateLegacyStateIfNeeded() {
        guard stateMigrationVersion < 1 else { return }

        let hasLegacyState = isCompleted || isBacklog || isOnHiatus
        let hasNewState = readingStateRawValue != 0 || publicationStatusRawValue != 0

        if !hasLegacyState && hasNewState {
            // 別端末で移行済みの値が同期されてきたケース。何も書き換えない。
            stateMigrationVersion = 1
            return
        }

        if isCompleted {
            // 旧「完結タブ」は実質「読了アーカイブ」として運用されていた
            readingStateRawValue = ReadingState.archived.rawValue
            publicationStatusRawValue = PublicationStatus.active.rawValue
        } else if isBacklog {
            readingStateRawValue = ReadingState.backlog.rawValue
            publicationStatusRawValue = isOnHiatus
                ? PublicationStatus.hiatus.rawValue
                : PublicationStatus.active.rawValue
        } else if isOnHiatus {
            readingStateRawValue = ReadingState.following.rawValue
            publicationStatusRawValue = PublicationStatus.hiatus.rawValue
        } else {
            // legacy も新フィールドも未設定 = 真の新規 / 初回起動。デフォルトで OK。
            readingStateRawValue = ReadingState.following.rawValue
            publicationStatusRawValue = PublicationStatus.active.rawValue
        }
        normalizeOneShotInvariants()
        stateMigrationVersion = 1
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        url: String = "",
        dayOfWeek: DayOfWeek = .monday,
        sortOrder: Int = 0,
        iconColor: String = "blue",
        publisher: String = "",
        imageData: Data? = nil,
        updateIntervalWeeks: Int = 1
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.dayOfWeekRawValue = dayOfWeek.rawValue
        self.sortOrder = sortOrder
        self.iconColor = iconColor
        self.publisher = publisher
        self.imageData = imageData
        self.updateIntervalWeeks = updateIntervalWeeks
        // 新規作成時は移行済み扱い
        self.stateMigrationVersion = 1
    }

}
