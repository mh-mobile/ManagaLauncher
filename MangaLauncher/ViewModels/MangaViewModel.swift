import Foundation
import SwiftUI
import SwiftData
import NotificationKit
#if canImport(WidgetKit)
import WidgetKit
#endif

@Observable
@MainActor
final class MangaViewModel {
    var selectedDay: DayOfWeek = .today
    // Note: 以下のプロパティは extension ファイルからの書き込みが必要なため internal にしている。
    // View 側から直接書き換えないこと。読み取りのみ OK。
    var refreshCounter = 0
    var hiddenIDs: Set<UUID> = []
    var deletedIDs: Set<UUID> = []
    var pendingDeleteEntries: [MangaEntry] = []
    var deleteTimer: Timer?
    var pendingDeleteComments: [MangaComment] = []
    var commentDeleteTimer: Timer?

    /// allEntries / allComments / allActivities の N+1 fetch を避けるため、
    /// refreshCounter に紐付けた簡易キャッシュ。
    /// refreshCounter が変わるとキャッシュは無効化される。
    @ObservationIgnored private var cacheVersion = -1
    @ObservationIgnored private var cachedEntries: [MangaEntry]?
    /// extension ファイル (Comments / Publisher) から書き込まれるキャッシュは internal のまま。
    @ObservationIgnored var cachedComments: [MangaComment]?
    @ObservationIgnored private var cachedActivities: [ReadingActivity]?
    /// publisher 名 → アイコン Data の辞書キャッシュ。
    @ObservationIgnored var cachedPublisherIcons: [String: Data?]?

    /// 直近の重大エラー（移行/インポート/同期）。View 側で alert 表示する用。
    var lastError: AppError?

    var browserContext: BrowserContext?

    private(set) var modelContext: ModelContext
    @ObservationIgnored var didRunStartupMigrations = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reloadHiddenIDs()
        reloadDeletedIDs()
        // 起動時の重い処理 (migration / backfill) は init では実行しない。
        // CloudKit 同期前のローカル DB を書き換えると、cloud で持っている値を
        // デフォルトで上書きしてしまうリスクがある (Vision Pro 初回起動などで観測)。
        // 代わりに scenePhase = .active のタイミングで `runStartupMigrationsIfNeeded()`
        // を呼んでもらう。
    }

    // MARK: - Common Entry Filter

    /// フェッチ結果から、削除予定・非表示・ソフトデリート済み・重複を除外する共通フィルタ。
    /// `excludeHidden: false` にすると hiddenIDs による除外をスキップする（hiddenEntries 用）。
    private func filterEntries(_ entries: [MangaEntry], excludeHidden: Bool = true) -> [MangaEntry] {
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        let currentDeletedIDs = deletedIDs
        let currentHiddenIDs = excludeHidden ? hiddenIDs : []
        var seenIDs = Set<UUID>()
        return entries.filter { entry in
            guard !currentHiddenIDs.contains(entry.id) else { return false }
            guard !pendingIDs.contains(entry.id) else { return false }
            guard !currentDeletedIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }
    }

    // MARK: - Core Fetch

    /// 曜日ごとの「今追っかけている」エントリを取得する。
    /// 連載中 × 追っかけ中のみ。完結/休載/読了/積読 はホームの曜日タブには出さない。
    func fetchEntries(for day: DayOfWeek) -> [MangaEntry] {
        let _ = refreshCounter
        let dayRawValue = day.rawValue
        let followingRaw = ReadingState.following.rawValue
        let activeRaw = PublicationStatus.active.rawValue
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate {
                $0.dayOfWeekRawValue == dayRawValue
                    && $0.readingStateRawValue == followingRaw
                    && $0.publicationStatusRawValue == activeRaw
                    && $0.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return filterEntries(modelContext.fetchLogged(descriptor))
    }

    func publishers(for day: DayOfWeek) -> [String] {
        PublisherIndex.counts(from: fetchEntries(for: day)).map(\.publisher)
    }

    func allEntries() -> [MangaEntry] {
        invalidateCacheIfStale()
        if let cached = cachedEntries { return cached }
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isHidden == false },
            sortBy: [SortDescriptor(\.lastReadDate, order: .reverse), SortDescriptor(\.name)]
        )
        let result = filterEntries(modelContext.fetchLogged(descriptor))
        cachedEntries = result
        return result
    }

    func hiddenEntries() -> [MangaEntry] {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.isHidden == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return filterEntries(modelContext.fetchLogged(descriptor), excludeHidden: false)
    }

    func findEntry(by id: UUID) -> MangaEntry? {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return modelContext.fetchLogged(descriptor).first
    }

    func findEntries(by ids: Set<UUID>) -> [UUID: MangaEntry] {
        let idArray = Array(ids)
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { idArray.contains($0.id) }
        )
        let entries = modelContext.fetchLogged(descriptor)
        return Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func totalEntryCount() -> Int {
        let _ = refreshCounter
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        return filterEntries(modelContext.fetchLogged(descriptor)).count
    }

    /// タイムラインのアクティビティドットや日別集計に使う全 ReadingActivity。
    func allActivities() -> [ReadingActivity] {
        invalidateCacheIfStale()
        if let cached = cachedActivities { return cached }
        let descriptor = FetchDescriptor<ReadingActivity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let result = modelContext.fetchLogged(descriptor)
        cachedActivities = result
        return result
    }

    // MARK: - Hidden / Deleted ID Management

    func reloadHiddenIDs() {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.isHidden == true && $0.deletedAt == nil }
        )
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        hiddenIDs = Set(entries.map(\.id))
    }

    func reloadDeletedIDs() {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt != nil }
        )
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        deletedIDs = Set(entries.map(\.id))
    }

    // MARK: - Unread Count & Stats

    func unreadCount(for day: DayOfWeek) -> Int {
        unreadEntries(for: day).count
    }

    var stats: ReadingStatsProvider {
        ReadingStatsProvider(modelContext: modelContext)
    }

    // MARK: - Notifications & Refresh

    func rescheduleNotifications() {
        var counts: [Int: Int] = [:]
        var displayNames: [Int: String] = [:]
        for day in DayOfWeek.orderedDays {
            counts[day.rawValue] = fetchEntries(for: day).count
            displayNames[day.rawValue] = day.displayName
        }
        NotificationManager.scheduleNotifications(entryCounts: counts, dayDisplayNames: displayNames)
    }

    func notifyChange() {
        refreshCounter += 1
    }

    func refresh() {
        modelContext = ModelContext(modelContext.container)
        reloadHiddenIDs()
        reloadDeletedIDs()
        refreshCounter += 1
    }

    // MARK: - Save

    /// entry が属する ModelContext で先に保存してから、viewModel の modelContext も保存する。
    /// `refresh()` で `modelContext` が差し替わった後、UI が保持する entry が
    /// 旧コンテキストに残っている場合の不整合を防ぐ共通ヘルパー。
    /// `updateEntry` / `setHidden` / `setPersonalRating` 等と同じパターン。
    func saveEntryChange(for entry: MangaEntry) {
        if let entryCtx = entry.modelContext, entryCtx !== modelContext {
            do {
                try entryCtx.save()
            } catch {
                print("[MangaViewModel] saveEntryChange entryCtx save failed: \(error)")
                lastError = .save(error)
                return
            }
        }
        save()
    }

    func save() {
        do {
            try modelContext.save()
        } catch {
            print("[MangaViewModel] save failed: \(error)")
            lastError = .save(error)
            return
        }
        refreshCounter += 1
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        BadgeManager.updateBadge(unreadCount: unreadCount(for: .today))
        rescheduleNotifications()
    }

    // MARK: - Cache Invalidation

    func invalidateCacheIfStale() {
        let _ = refreshCounter
        if cacheVersion != refreshCounter {
            cacheVersion = refreshCounter
            cachedEntries = nil
            cachedComments = nil
            cachedActivities = nil
            cachedPublisherIcons = nil
        }
    }

    // MARK: - Delete Timer (internal)

    /// Undo 猶予時間（秒）。この間に「元に戻す」が押されなければ確定削除する。
    static let undoGracePeriod: TimeInterval = 5.0

    func restartDeleteTimer() {
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: Self.undoGracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitPendingDeletes()
            }
        }
    }

    func restartCommentDeleteTimer() {
        commentDeleteTimer?.invalidate()
        commentDeleteTimer = Timer.scheduledTimer(withTimeInterval: Self.undoGracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitPendingCommentDeletes()
            }
        }
    }

    /// `DayOfWeek.orderedDays` (Mon→Sun) における順序 index を返す。
    static func weekdayOrderIndex(rawValue: Int) -> Int {
        (rawValue + 6) % 7
    }
}

// MARK: - MangaURLOpener Factory

extension MangaURLOpener {
    @MainActor
    static func make(
        browserMode: String,
        openURL: OpenURLAction,
        safariURL: Binding<URL?>,
        viewModel: MangaViewModel
    ) -> MangaURLOpener {
        MangaURLOpener(
            browserMode: browserMode,
            openURL: openURL,
            onSafariURL: { safariURL.wrappedValue = $0 },
            onQuickView: { viewModel.browserContext = $0 },
            entryLookup: { url in
                guard let e = viewModel.allEntries().first(where: { $0.url == url }) else { return nil }
                return (e.name, e.publisher, e.imageData)
            }
        )
    }
}
