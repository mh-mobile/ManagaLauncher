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
    private(set) var refreshCounter = 0
    private(set) var hiddenIDs: Set<UUID> = []
    private(set) var deletedIDs: Set<UUID> = []
    var pendingDeleteEntries: [MangaEntry] = []
    private var deleteTimer: Timer?
    var pendingDeleteComments: [MangaComment] = []
    private var commentDeleteTimer: Timer?

    /// allEntries / allComments / allActivities の N+1 fetch を避けるため、
    /// refreshCounter に紐付けた簡易キャッシュ。
    /// refreshCounter が変わるとキャッシュは無効化される。
    @ObservationIgnored private var cacheVersion = -1
    @ObservationIgnored private var cachedEntries: [MangaEntry]?
    @ObservationIgnored private var cachedComments: [MangaComment]?
    @ObservationIgnored private var cachedActivities: [ReadingActivity]?
    /// publisher 名 → アイコン Data の辞書キャッシュ。一覧/chip でセル毎に
    /// `publisherIcon(for:)` が呼ばれて N+1 fetch になるのを防ぐ。
    /// nil 値は「設定無し」を表す（fetch 結果が nil でも 2 回目を走らせない）。
    @ObservationIgnored private var cachedPublisherIcons: [String: Data?]?

    /// 直近の重大エラー（移行/インポート/同期）。View 側で alert 表示する用。
    var lastError: AppError?

    var browserContext: BrowserContext?

    private(set) var modelContext: ModelContext
    @ObservationIgnored private var didRunStartupMigrations = false

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

    /// 起動後 1 回だけ実行する重い初期化処理。
    /// 初回 active phase で呼ばれることを想定 (アプリ側で onAppear / scenePhase 監視)。
    func runStartupMigrationsIfNeeded() {
        guard !didRunStartupMigrations else { return }
        didRunStartupMigrations = true
        migrateLegacyStateIfNeeded()
        backfillMemoUpdatedAtIfNeeded()
        purgeExpiredSoftDeletes()
    }

    /// 旧 Bool 状態（isOnHiatus / isCompleted / isBacklog）を
    /// publicationStatus / readingState に一括移行する。
    private func migrateLegacyStateIfNeeded() {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.stateMigrationVersion < 1 }
        )
        let pending: [MangaEntry]
        do {
            pending = try modelContext.fetch(descriptor)
        } catch {
            print("[MangaViewModel] state migration fetch failed: \(error)")
            lastError = .migration(error)
            return
        }
        guard !pending.isEmpty else { return }
        for entry in pending {
            entry.migrateLegacyStateIfNeeded()
        }
        do {
            try modelContext.save()
        } catch {
            print("[MangaViewModel] state migration save failed: \(error)")
            lastError = .migration(error)
        }
    }

    /// memoUpdatedAt 追加前に書かれたメモには nil が入っているので、
    /// 起動時に一度だけ現在時刻でバックフィルする。
    /// （正確な編集日時は分からないが、次の編集で正しい値に上書きされる）
    private func backfillMemoUpdatedAtIfNeeded() {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.memo != "" && $0.memoUpdatedAt == nil }
        )
        let pending: [MangaEntry]
        do {
            pending = try modelContext.fetch(descriptor)
        } catch {
            print("[MangaViewModel] memo backfill fetch failed: \(error)")
            lastError = .migration(error)
            return
        }
        guard !pending.isEmpty else { return }
        let now = Date()
        for entry in pending {
            entry.memoUpdatedAt = now
        }
        do {
            try modelContext.save()
        } catch {
            print("[MangaViewModel] memo backfill save failed: \(error)")
            lastError = .migration(error)
        }
    }

    /// 曜日ごとの「今追っかけている」エントリを取得する。
    /// 連載中 × 追っかけ中のみ。完結/休載/読了/積読 はホームの曜日タブには出さない。
    func fetchEntries(for day: DayOfWeek) -> [MangaEntry] {
        let _ = refreshCounter
        let dayRawValue = day.rawValue
        // #Predicate は enum case を直接受け付けないので、ローカル let でキャプチャして意味を明示する
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
        let results = modelContext.fetchLogged(descriptor)
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        let currentHiddenIDs = hiddenIDs
        let currentDeletedIDs = deletedIDs
        var seenIDs = Set<UUID>()
        return results.filter { entry in
            guard !currentHiddenIDs.contains(entry.id) else { return false }
            guard !pendingIDs.contains(entry.id) else { return false }
            guard !currentDeletedIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }
    }

    /// 掲載状況の付け替え
    func setPublicationStatus(_ entry: MangaEntry, to status: PublicationStatus) {
        entry.publicationStatus = status
        save()
    }

    /// 読書状況の付け替え
    func setReadingState(_ entry: MangaEntry, to state: ReadingState) {
        entry.readingState = state
        // フォーカス積読は readingState == .backlog 前提なので、
        // 積読から外れた瞬間に自動でフォーカス解除する
        if state != .backlog {
            entry.isFocused = false
            entry.focusedAt = nil
        }
        save()
    }

    /// 非表示フラグの切り替え（refresh() は呼ばない）
    func setHidden(_ entry: MangaEntry, isHidden: Bool) {
        entry.isHidden = isHidden
        if isHidden {
            hiddenIDs.insert(entry.id)
        } else {
            hiddenIDs.remove(entry.id)
        }
        // entry が属するコンテキストで保存する（refresh() で modelContext が
        // 差し替わっている場合、self.modelContext と異なる可能性がある）
        do {
            if let ctx = entry.modelContext {
                try ctx.save()
            } else {
                try modelContext.save()
            }
        } catch {
            print("[MangaViewModel] setHidden save failed: \(error)")
        }
        refreshCounter += 1
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        BadgeManager.updateBadge(unreadCount: unreadCount(for: .today))
        rescheduleNotifications()
    }

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

    func hiddenEntries() -> [MangaEntry] {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.isHidden == true },
            sortBy: [SortDescriptor(\.name)]
        )
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        let currentDeletedIDs = deletedIDs
        return modelContext.fetchLogged(descriptor).filter { entry in
            !pendingIDs.contains(entry.id) && !currentDeletedIDs.contains(entry.id)
        }
    }

    func recordSpecialEpisode(_ entry: MangaEntry, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        entry.episodeLabel = trimmed
        entry.lastReadDate = now
        let activity = ReadingActivity(
            date: now,
            mangaName: entry.name,
            mangaEntryID: entry.id,
            episodeLabel: trimmed
        )
        modelContext.insert(activity)
        save()
    }

    func recordEpisodeRead(_ entry: MangaEntry, episodeNumber: Int) {
        let now = Date()
        entry.lastReadDate = now
        let activity = ReadingActivity(
            date: now,
            mangaName: entry.name,
            mangaEntryID: entry.id,
            episodeNumber: episodeNumber
        )
        modelContext.insert(activity)
        save()
    }

    func incrementEpisode(_ entry: MangaEntry) {
        let newEpisode = (entry.currentEpisode ?? 0) + 1
        entry.currentEpisode = newEpisode
        entry.episodeLabel = nil
        entry.lastReadDate = Date()
        let activity = ReadingActivity(
            date: Date(),
            mangaName: entry.name,
            mangaEntryID: entry.id,
            episodeNumber: newEpisode
        )
        modelContext.insert(activity)
        save()
    }

    func addEntry(name: String, url: String, days: Set<DayOfWeek>, iconColor: String, publisher: String = "", imageData: Data? = nil, updateIntervalWeeks: Int = 1, nextExpectedUpdate: Date? = nil, publicationStatus: PublicationStatus = .active, readingState: ReadingState = .following, isOneShot: Bool = false, memo: String = "", currentEpisode: Int? = nil, episodeLabel: String? = nil) {
        for day in days {
            // 同一URL + 同一曜日の重複登録を防止（状態問わず全エントリ対象）
            if allEntries().contains(where: { $0.dayOfWeek == day && $0.url == url }) { continue }
            let existingEntries = fetchEntries(for: day)
            let maxOrder = existingEntries.map(\.sortOrder).max() ?? -1
            let entry = MangaEntry(
                name: name,
                url: url,
                dayOfWeek: day,
                sortOrder: maxOrder + 1,
                iconColor: iconColor,
                publisher: publisher,
                imageData: imageData,
                updateIntervalWeeks: updateIntervalWeeks
            )
            entry.nextExpectedUpdate = nextExpectedUpdate
            entry.publicationStatus = publicationStatus
            entry.readingState = readingState
            entry.isOneShot = isOneShot
            entry.normalizeOneShotInvariants()
            entry.memo = memo
            if !memo.isEmpty {
                entry.memoUpdatedAt = Date()
            }
            entry.currentEpisode = currentEpisode
            entry.episodeLabel = episodeLabel
            modelContext.insert(entry)
        }
        save()
    }

    func updateEntry(
        _ entry: MangaEntry,
        name: String,
        url: String,
        dayOfWeek: DayOfWeek,
        iconColor: String,
        publisher: String = "",
        imageData: Data? = nil,
        updateIntervalWeeks: Int = 1,
        nextExpectedUpdate: Date? = nil,
        isOneShot: Bool,
        publicationStatus: PublicationStatus,
        readingState: ReadingState,
        memo: String,
        currentEpisode: Int? = nil,
        episodeLabel: String? = nil,
        markAsReadOnSave: Bool = false
    ) {
        // URL または曜日が変更された場合、同一URL+曜日の重複を防止
        let urlOrDayChanged = entry.url != url || entry.dayOfWeek != dayOfWeek
        if urlOrDayChanged {
            let conflict = allEntries().contains { existing in
                existing.id != entry.id && existing.dayOfWeek == dayOfWeek && existing.url == url
            }
            if conflict { return }
        }

        let memoChanged = entry.memo != memo
        entry.name = name
        entry.url = url
        entry.dayOfWeek = dayOfWeek
        entry.iconColor = iconColor
        entry.publisher = publisher
        entry.imageData = imageData
        entry.updateIntervalWeeks = updateIntervalWeeks
        entry.nextExpectedUpdate = nextExpectedUpdate
        entry.isOneShot = isOneShot
        entry.publicationStatus = publicationStatus
        entry.readingState = readingState
        // 読み切りの invariants (publicationStatus=.active, readingState != .backlog) を強制
        entry.normalizeOneShotInvariants()
        // フォーカスは積読限定のフラグなので、積読から外れたら解除する
        if entry.readingState != .backlog {
            entry.isFocused = false
            entry.focusedAt = nil
        }
        entry.memo = memo
        if memoChanged {
            entry.memoUpdatedAt = memo.isEmpty ? nil : Date()
        }
        entry.currentEpisode = currentEpisode
        entry.episodeLabel = episodeLabel

        // 「保存時に既読にする」を同一トランザクション内で処理し、save() を1回に統合
        if markAsReadOnSave, entry.modelContext != nil {
            let now = Date()
            let trimmedLabel = episodeLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let label = trimmedLabel, !label.isEmpty {
                entry.episodeLabel = label
                entry.lastReadDate = now
                let activity = ReadingActivity(
                    date: now,
                    mangaName: entry.name,
                    mangaEntryID: entry.id,
                    episodeLabel: label
                )
                // ReadingActivity は entry と同じ context に挿入
                (entry.modelContext ?? modelContext).insert(activity)
            } else if let ep = currentEpisode {
                entry.lastReadDate = now
                let activity = ReadingActivity(
                    date: now,
                    mangaName: entry.name,
                    mangaEntryID: entry.id,
                    episodeNumber: ep
                )
                (entry.modelContext ?? modelContext).insert(activity)
            } else {
                entry.lastReadDate = now
            }
        }

        // entry が属するコンテキストで保存する（refresh() で modelContext が
        // 差し替わっている場合、self.modelContext と異なる可能性がある）
        if let entryCtx = entry.modelContext, entryCtx !== modelContext {
            do {
                try entryCtx.save()
            } catch {
                print("[MangaViewModel] updateEntry entryCtx save failed: \(error)")
                lastError = .save(error)
                return
            }
        }
        save()
    }

    func publishers(for day: DayOfWeek) -> [String] {
        let entries = fetchEntries(for: day)
        return Set(entries.map(\.publisher)).filter { !$0.isEmpty }.sorted()
    }

    func allEntries() -> [MangaEntry] {
        invalidateCacheIfStale()
        if let cached = cachedEntries { return cached }
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isHidden == false },
            sortBy: [SortDescriptor(\.lastReadDate, order: .reverse), SortDescriptor(\.name)]
        )
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        let currentHiddenIDs = hiddenIDs
        let currentDeletedIDs = deletedIDs
        var seenIDs = Set<UUID>()
        let result = modelContext.fetchLogged(descriptor).filter { entry in
            guard !currentHiddenIDs.contains(entry.id) else { return false }
            guard !pendingIDs.contains(entry.id) else { return false }
            guard !currentDeletedIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }
        cachedEntries = result
        return result
    }

    func allPublishers() -> [String] {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let entries = modelContext.fetchLogged(descriptor)
        let currentHiddenIDs = hiddenIDs
        let currentDeletedIDs = deletedIDs
        let publishers = Set(entries.filter { !currentHiddenIDs.contains($0.id) && !currentDeletedIDs.contains($0.id) }.map(\.publisher)).filter { !$0.isEmpty }
        return publishers.sorted()
    }

    /// 掲載誌を統合する。`from` の名前を持つ全エントリの publisher を `to` に一括変更する。
    /// soft-delete されたエントリも含めて変更するのは、restore したときに「古い publisher 名で蘇る」
    /// ゴーストを作らないため（統合は user の所有データ全体に対する操作と捉える）。
    /// 統合元の `PublisherMetadata`（アイコン情報）も削除する。統合先の metadata はそのまま維持。
    func mergePublisher(from oldName: String, to newName: String) {
        guard !oldName.isEmpty, !newName.isEmpty, oldName != newName else { return }
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.publisher == oldName }
        )
        let entries = modelContext.fetchLogged(descriptor)
        guard !entries.isEmpty else { return }
        for entry in entries {
            entry.publisher = newName
        }
        // 統合元の metadata を削除（統合先のアイコンを維持）
        deletePublisherMetadata(name: oldName)
        save()
    }

    /// `mergePublisher` の前置確認用。統合される件数（soft-delete 込み）を返す。
    /// View 側の確認アラートで「○件を統合します」を表示するために使う。
    func mergePublisherPreviewCount(for oldName: String) -> Int {
        guard !oldName.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.publisher == oldName }
        )
        return modelContext.fetchLogged(descriptor).count
    }

    // MARK: - Publisher Metadata

    /// 指定 publisher のアイコン Data を取得（表示パスから毎回呼ばれる前提、軽量）。
    /// 初回呼び出しで全 PublisherMetadata を一括 fetch して `cachedPublisherIcons`
    /// に辞書化する。同 render 内の複数 publisher 表示で N 回 fetch を避ける。
    func publisherIcon(for name: String) -> Data? {
        guard !name.isEmpty else { return nil }
        return loadAllPublisherIcons()[name] ?? nil
    }

    /// 指定 publisher にアイコンが設定されているか。merge 確認文言の分岐などで使う。
    func publisherHasIcon(name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return (loadAllPublisherIcons()[name] ?? nil) != nil
    }

    /// publisher 名 → iconData の辞書を返す（キャッシュ済みならそれを返す）。
    /// `refreshCounter` が変わるとキャッシュは破棄される。
    /// 同名重複時の優先順位は `publisherMetadata(for:)` と統一:
    ///   1. iconData あり優先
    ///   2. 同条件なら updatedAt の新しい方
    /// 事前ソート + 先勝ち insert で実現する。
    private func loadAllPublisherIcons() -> [String: Data?] {
        invalidateCacheIfStale()
        if let cached = cachedPublisherIcons { return cached }
        let descriptor = FetchDescriptor<PublisherMetadata>()
        let records = modelContext.fetchLogged(descriptor)
        let sorted = records.sorted { lhs, rhs in
            let lhsHas = lhs.iconData != nil
            let rhsHas = rhs.iconData != nil
            if lhsHas != rhsHas { return lhsHas }
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }
        var result: [String: Data?] = [:]
        for record in sorted where result[record.name] == nil {
            result[record.name] = record.iconData
        }
        cachedPublisherIcons = result
        return result
    }

    /// 指定 publisher のメタデータレコード。重複時は iconData 持ち + 新しい updatedAt を優先。
    /// CloudKit race で複数できる可能性に備えた soft de-dup。
    private func publisherMetadata(for name: String) -> PublisherMetadata? {
        let descriptor = FetchDescriptor<PublisherMetadata>(
            predicate: #Predicate { $0.name == name }
        )
        let results = modelContext.fetchLogged(descriptor)
        if results.count <= 1 { return results.first }
        return results.sorted { lhs, rhs in
            let lhsHas = lhs.iconData != nil
            let rhsHas = rhs.iconData != nil
            if lhsHas != rhsHas { return lhsHas }
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }.first
    }

    /// アイコンを保存。imageData は整形済み (PublisherIconService 経由) を期待。
    /// 既存 record があれば update、なければ insert。
    func setPublisherIcon(name: String, imageData: Data, sourceURL: String? = nil) {
        guard !name.isEmpty else { return }
        if let existing = publisherMetadata(for: name) {
            existing.iconData = imageData
            if let sourceURL { existing.sourceURL = sourceURL }
            existing.updatedAt = Date()
        } else {
            let meta = PublisherMetadata(name: name, iconData: imageData, sourceURL: sourceURL)
            modelContext.insert(meta)
        }
        save()
    }

    /// アイコンのみクリア（record 自体は残す: sourceURL を保持して再取得しやすくするため）。
    func clearPublisherIcon(name: String) {
        guard let meta = publisherMetadata(for: name) else { return }
        meta.iconData = nil
        meta.updatedAt = Date()
        save()
    }

    /// メタデータレコードを完全削除（mergePublisher / deleteAllEntries 用、private）。
    private func deletePublisherMetadata(name: String) {
        let descriptor = FetchDescriptor<PublisherMetadata>(
            predicate: #Predicate { $0.name == name }
        )
        for meta in modelContext.fetchLogged(descriptor) {
            modelContext.delete(meta)
        }
    }

    func deleteEntry(_ entry: MangaEntry) {
        entry.deletedAt = Date()
        deletedIDs.insert(entry.id)
        hiddenIDs.remove(entry.id)
        save()
    }

    func queueDelete(_ entry: MangaEntry) {
        pendingDeleteEntries.append(entry)
        refreshCounter += 1
        restartDeleteTimer()
    }

    func undoPendingDeletes() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        pendingDeleteEntries.removeAll()
        refreshCounter += 1
    }

    func commitPendingDeletes() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        for entry in pendingDeleteEntries {
            entry.deletedAt = Date()
            deletedIDs.insert(entry.id)
            hiddenIDs.remove(entry.id)
        }
        pendingDeleteEntries.removeAll()
        save()
    }

    private func restartDeleteTimer() {
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitPendingDeletes()
            }
        }
    }

    // MARK: - Soft Delete

    func permanentlyDelete(_ entry: MangaEntry) {
        permanentlyDeleteWithoutSave(entry)
        save()
    }

    private func permanentlyDeleteWithoutSave(_ entry: MangaEntry) {
        deletedIDs.remove(entry.id)
        hiddenIDs.remove(entry.id)
        let entryID = entry.id
        let activityDescriptor = FetchDescriptor<ReadingActivity>(predicate: #Predicate { $0.mangaEntryID == entryID })
        if let activities = try? modelContext.fetch(activityDescriptor) {
            for activity in activities { modelContext.delete(activity) }
        }
        let commentDescriptor = FetchDescriptor<MangaComment>(predicate: #Predicate { $0.mangaEntryID == entryID })
        if let comments = try? modelContext.fetch(commentDescriptor) {
            for comment in comments { modelContext.delete(comment) }
        }
        let linkDescriptor = FetchDescriptor<MangaLink>(predicate: #Predicate { $0.mangaEntryID == entryID })
        if let links = try? modelContext.fetch(linkDescriptor) {
            for link in links { modelContext.delete(link) }
        }
        modelContext.delete(entry)
    }

    func restoreEntry(_ entry: MangaEntry) {
        restoreEntryWithoutSave(entry)
        save()
    }

    private func restoreEntryWithoutSave(_ entry: MangaEntry) {
        entry.deletedAt = nil
        deletedIDs.remove(entry.id)
        if entry.isHidden {
            hiddenIDs.insert(entry.id)
        }
        // Recalculate sortOrder to end of its day group
        let day = entry.dayOfWeekRawValue
        let descriptor = FetchDescriptor<MangaEntry>(predicate: #Predicate { $0.dayOfWeekRawValue == day && $0.deletedAt == nil })
        let maxOrder = (try? modelContext.fetch(descriptor))?.map(\.sortOrder).max() ?? -1
        entry.sortOrder = maxOrder + 1
    }

    func restoreEntries(_ entries: [MangaEntry]) {
        for entry in entries { restoreEntryWithoutSave(entry) }
        save()
    }

    func permanentlyDeleteEntries(_ entries: [MangaEntry]) {
        for entry in entries { permanentlyDeleteWithoutSave(entry) }
        save()
    }

    func deletedEntries() -> [MangaEntry] {
        let currentDeletedIDs = deletedIDs
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt != nil }
        )
        let results = modelContext.fetchLogged(descriptor)
        // SwiftData stale fetch 対策: in-memory deletedIDs でも照合
        return results.filter { currentDeletedIDs.contains($0.id) }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    /// 非表示の削除済みエントリが存在するか
    func hasHiddenDeletedEntries() -> Bool {
        deletedEntries().contains { $0.isHidden }
    }

    func deletedEntryCount() -> Int {
        deletedEntries().count
    }

    func purgeExpiredSoftDeletes() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let descriptor = FetchDescriptor<MangaEntry>(predicate: #Predicate { $0.deletedAt != nil && $0.deletedAt! < cutoff })
        guard let expired = try? modelContext.fetch(descriptor), !expired.isEmpty else { return }
        for entry in expired {
            permanentlyDeleteWithoutSave(entry)
        }
        save()
    }

    /// 別の曜日に移動。曜日のみ変更し、状態は触らない。
    func moveEntryToDay(_ entry: MangaEntry, to newDay: DayOfWeek, at targetEntry: MangaEntry? = nil) {
        entry.dayOfWeek = newDay
        entry.resetNextUpdate()
        var entries = fetchEntries(for: newDay)
        if !entries.contains(where: { $0.id == entry.id }) {
            if let targetEntry, let targetIndex = entries.firstIndex(where: { $0.id == targetEntry.id }) {
                entries.insert(entry, at: targetIndex)
            } else {
                entries.append(entry)
            }
        }
        for (index, e) in entries.enumerated() {
            e.sortOrder = index
        }
        save()
    }

    func moveEntries(for day: DayOfWeek, from source: IndexSet, to destination: Int) {
        var entries = fetchEntries(for: day)
        entries.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in entries.enumerated() {
            entry.sortOrder = index
        }
        save()
    }

    func deleteAllEntries() {
        let descriptor = FetchDescriptor<MangaEntry>()
        for entry in modelContext.fetchLogged(descriptor) {
            modelContext.delete(entry)
        }
        let activityDescriptor = FetchDescriptor<ReadingActivity>()
        for activity in modelContext.fetchLogged(activityDescriptor) {
            modelContext.delete(activity)
        }
        let commentDescriptor = FetchDescriptor<MangaComment>()
        for comment in modelContext.fetchLogged(commentDescriptor) {
            modelContext.delete(comment)
        }
        let metaDescriptor = FetchDescriptor<PublisherMetadata>()
        for meta in modelContext.fetchLogged(metaDescriptor) {
            modelContext.delete(meta)
        }
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastStreakShownDate)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.shownMilestones)
        deletedIDs.removeAll()
        hiddenIDs.removeAll()
        do {
            try modelContext.save()
        } catch {
            print("[MangaViewModel] deleteAllEntries save failed: \(error)")
        }
        refreshCounter += 1
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        BadgeManager.updateBadge(unreadCount: 0)
        NotificationManager.scheduleNotifications(entryCounts: [:], dayDisplayNames: [:])
    }

    func totalEntryCount() -> Int {
        let _ = refreshCounter
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let results = modelContext.fetchLogged(descriptor)
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        let currentHiddenIDs = hiddenIDs
        let currentDeletedIDs = deletedIDs
        var seenIDs = Set<UUID>()
        return results.filter { entry in
            guard !currentHiddenIDs.contains(entry.id) else { return false }
            guard !pendingIDs.contains(entry.id) else { return false }
            guard !currentDeletedIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }.count
    }

    func exportBackupData() -> Data? {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.dayOfWeekRawValue), SortDescriptor(\.sortOrder)]
        )
        let entries = modelContext.fetchLogged(descriptor)
        guard !entries.isEmpty else { return nil }
        let activeEntryIDs = Set(entries.map(\.id))
        let activityDescriptor = FetchDescriptor<ReadingActivity>(sortBy: [SortDescriptor(\.date)])
        let activities = modelContext.fetchLogged(activityDescriptor).filter { activeEntryIDs.contains($0.mangaEntryID) }
        let commentDescriptor = FetchDescriptor<MangaComment>(sortBy: [SortDescriptor(\.createdAt)])
        let comments = modelContext.fetchLogged(commentDescriptor).filter { activeEntryIDs.contains($0.mangaEntryID) }
        let linkDescriptor = FetchDescriptor<MangaLink>(sortBy: [SortDescriptor(\.sortOrder)])
        let links = modelContext.fetchLogged(linkDescriptor).filter { activeEntryIDs.contains($0.mangaEntryID) }
        // Publisher metadata は entry に紐付かない (name で join) ので、すべて含める
        let metaDescriptor = FetchDescriptor<PublisherMetadata>(sortBy: [SortDescriptor(\.name)])
        let publisherMetadata = modelContext.fetchLogged(metaDescriptor)
        let backup = BackupData.from(entries, activities: activities, comments: comments, links: links, publisherMetadata: publisherMetadata)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    func importBackupData(_ data: Data) -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupData.self, from: data) else { return 0 }

        let existingIDs = Set(modelContext.fetchLogged(FetchDescriptor<MangaEntry>()).map(\.id))

        var importedCount = 0
        for backupEntry in backup.entries {
            guard !existingIDs.contains(backupEntry.id) else { continue }
            let entry = MangaEntry(
                id: backupEntry.id,
                name: backupEntry.name,
                url: backupEntry.url,
                dayOfWeek: DayOfWeek(rawValue: backupEntry.dayOfWeekRawValue) ?? .monday,
                sortOrder: backupEntry.sortOrder,
                iconColor: backupEntry.iconColor,
                publisher: backupEntry.publisher,
                imageData: backupEntry.imageData,
                updateIntervalWeeks: backupEntry.updateIntervalWeeks
            )
            entry.lastReadDate = backupEntry.lastReadDate
            entry.nextExpectedUpdate = backupEntry.nextExpectedUpdate
            entry.isOneShot = backupEntry.isOneShot ?? false
            entry.memo = backupEntry.memo ?? ""
            entry.memoUpdatedAt = backupEntry.memoUpdatedAt
            entry.currentEpisode = backupEntry.currentEpisode
            entry.episodeLabel = backupEntry.episodeLabel
            entry.isHidden = backupEntry.isHidden ?? false
            // v6+ バックアップは publicationStatusRawValue / readingStateRawValue を authoritative とする。
            // 両方 nil のときだけ v5 以前の legacy Bool から導出する。
            // 通常 export 側は両方を必ず書くので片方 nil は現実にはほぼ起こらないが、
            // 手動編集や他実装からの破損対策として欠けた側はデフォルトで補っておく。
            if backupEntry.publicationStatusRawValue != nil || backupEntry.readingStateRawValue != nil {
                entry.publicationStatusRawValue = backupEntry.publicationStatusRawValue
                    ?? PublicationStatus.active.rawValue
                entry.readingStateRawValue = backupEntry.readingStateRawValue
                    ?? ReadingState.following.rawValue
                entry.stateMigrationVersion = 1
            } else {
                entry.isOnHiatus = backupEntry.isOnHiatus ?? false
                entry.isCompleted = backupEntry.isCompleted ?? false
                entry.isBacklog = backupEntry.isBacklog ?? false
                entry.stateMigrationVersion = 0
                entry.migrateLegacyStateIfNeeded()
            }
            modelContext.insert(entry)
            importedCount += 1
        }
        if let backupComments = backup.comments {
            let existingCommentIDs = Set(modelContext.fetchLogged(FetchDescriptor<MangaComment>()).map(\.id))
            for backupComment in backupComments {
                guard !existingCommentIDs.contains(backupComment.id) else { continue }
                let comment = MangaComment(
                    mangaEntryID: backupComment.mangaEntryID,
                    content: backupComment.content,
                    createdAt: backupComment.createdAt
                )
                comment.id = backupComment.id
                comment.updatedAt = backupComment.updatedAt
                modelContext.insert(comment)
                importedCount += 1
            }
        }
        if let backupActivities = backup.activities {
            let existingActivityIDs = Set(modelContext.fetchLogged(FetchDescriptor<ReadingActivity>()).map(\.id))
            for backupActivity in backupActivities {
                guard !existingActivityIDs.contains(backupActivity.id) else { continue }
                let activity = ReadingActivity(
                    date: backupActivity.date,
                    mangaName: backupActivity.mangaName,
                    mangaEntryID: backupActivity.mangaEntryID,
                    episodeNumber: backupActivity.episodeNumber,
                    episodeLabel: backupActivity.episodeLabel
                )
                activity.id = backupActivity.id
                activity.timestamp = backupActivity.timestamp
                modelContext.insert(activity)
                importedCount += 1
            }
        }
        if let backupLinks = backup.links {
            var existingLinkIDs = Set(modelContext.fetchLogged(FetchDescriptor<MangaLink>()).map(\.id))
            for backupLink in backupLinks {
                guard !existingLinkIDs.contains(backupLink.id) else { continue }
                let link = MangaLink(
                    mangaEntryID: backupLink.mangaEntryID,
                    linkType: LinkType(rawValue: backupLink.linkTypeRawValue) ?? .other,
                    title: backupLink.title,
                    url: backupLink.url,
                    sortOrder: backupLink.sortOrder
                )
                link.id = backupLink.id
                link.createdAt = backupLink.createdAt
                link.updatedAt = backupLink.updatedAt
                modelContext.insert(link)
                existingLinkIDs.insert(backupLink.id)
                importedCount += 1
            }
        }
        // v15+ 掲載誌アイコン等のメタデータ。同名既存があればスキップ (in-place update はしない)。
        // backup 内に同名重複があるケース (CloudKit race 由来の重複を export したもの等) でも
        // 二重 insert にならないよう、insert 後に existingNames へ追加する。
        if let backupMetas = backup.publisherMetadata {
            var existingNames = Set(modelContext.fetchLogged(FetchDescriptor<PublisherMetadata>()).map(\.name))
            for backupMeta in backupMetas {
                guard !existingNames.contains(backupMeta.name) else { continue }
                let meta = PublisherMetadata(
                    name: backupMeta.name,
                    iconData: backupMeta.iconData,
                    sourceURL: backupMeta.sourceURL
                )
                meta.id = backupMeta.id
                meta.updatedAt = backupMeta.updatedAt
                modelContext.insert(meta)
                existingNames.insert(backupMeta.name)
                importedCount += 1
            }
        }
        if importedCount > 0 {
            save()
            reloadHiddenIDs()
            reloadDeletedIDs()
        }
        return importedCount
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

    func markAsRead(_ entry: MangaEntry) {
        entry.lastReadDate = Date()
        if !entry.isOneShot {
            entry.advanceToNextUpdate()
        }
        // 同日・同エントリのアクティビティが既に存在する場合は再 insert しない。
        // ReadingActivity.init は date を startOfDay に正規化するので、
        // predicate の比較は秒単位の揺らぎなく成立する。
        let today = Calendar.current.startOfDay(for: Date())
        let entryID = entry.id
        let existingDescriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.date == today && $0.mangaEntryID == entryID }
        )
        let hasExisting = !modelContext.fetchLogged(existingDescriptor).isEmpty
        if !hasExisting {
            let activity = ReadingActivity(
                date: Date(),
                mangaName: entry.name,
                mangaEntryID: entry.id
            )
            modelContext.insert(activity)
        }
        // 読み切りを既読にしたら自動で読了アーカイブへ
        if entry.isOneShot {
            entry.readingState = .archived
        }
        save()
    }

    func markAsUnread(_ entry: MangaEntry) {
        entry.lastReadDate = nil
        if entry.isOneShot {
            entry.readingState = .following
        }
        let today = Calendar.current.startOfDay(for: Date())
        let entryID = entry.id
        let descriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.date == today && $0.mangaEntryID == entryID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let activity = modelContext.fetchLogged(descriptor).first {
            modelContext.delete(activity)
        }
        save()
    }

    func unreadEntries(for day: DayOfWeek) -> [MangaEntry] {
        fetchEntries(for: day).filter { !$0.isRead }
    }

    /// 曜日横断の未読エントリ。Library から起動する全未読キャッチアップ用。
    /// 集計のソースは `allEntries()` と揃えて Library 「未読」セクションと件数が必ず一致するようにする
    /// （独立フェッチにすると `isHidden` 述語と in-memory `hiddenIDs` のズレで件数が食い違う）。
    ///
    /// 並び順の優先度:
    ///   1. 期日が古い順 (`nextExpectedUpdate` が nil のものは末尾)
    ///   2. UI 共通の曜日順 (`DayOfWeek.orderedDays` = Mon→Sun)
    ///   3. 同曜日内は `sortOrder` で安定化 (曜日タブと一致)
    func allUnreadEntries() -> [MangaEntry] {
        let _ = refreshCounter
        let unread = allEntries().filter {
            !$0.isRead
                && $0.readingState == .following
                && $0.publicationStatus == .active
        }
        return unread.sorted { lhs, rhs in
            switch (lhs.nextExpectedUpdate, rhs.nextExpectedUpdate) {
            case let (l?, r?) where l != r: return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: break
            }
            let lWeekday = Self.weekdayOrderIndex(rawValue: lhs.dayOfWeekRawValue)
            let rWeekday = Self.weekdayOrderIndex(rawValue: rhs.dayOfWeekRawValue)
            if lWeekday != rWeekday { return lWeekday < rWeekday }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    /// `allUnreadEntries()` と同じ集計ソースを使った件数のみの軽量版。
    /// Library のバッジ表示など毎レンダリング呼ばれる箇所では sort のコストを避けるためこちらを使う。
    func allUnreadCount() -> Int {
        let _ = refreshCounter
        return allEntries().lazy.filter {
            !$0.isRead
                && $0.readingState == .following
                && $0.publicationStatus == .active
        }.count
    }

    /// `DayOfWeek.orderedDays` (Mon→Sun) における順序 index を返す。
    /// `dayOfWeekRawValue` (Sun=0..Sat=6) のまま比較すると Sun が先頭になり、UI と並びがズレる。
    private static func weekdayOrderIndex(rawValue: Int) -> Int {
        // Sun(0) → 6, Mon(1) → 0, Tue(2) → 1, ..., Sat(6) → 5
        (rawValue + 6) % 7
    }

    // MARK: - Focused Backlog

    /// 同時にフォーカス指定できる積読の上限本数。
    static let maxFocusedBacklogCount = 3

    /// フォーカス中の積読エントリ。`focusedAt` 降順（新しくフォーカスしたものが先頭）。
    /// 集計ソースを `allEntries()` に揃えることで、ソフトデリート/hidden の整合性を担保する。
    func focusedBacklogEntries() -> [MangaEntry] {
        let _ = refreshCounter
        return allEntries()
            .filter { $0.isFocused && $0.readingState == .backlog }
            .sorted { ($0.focusedAt ?? .distantPast) > ($1.focusedAt ?? .distantPast) }
    }

    func focusedBacklogCount() -> Int {
        let _ = refreshCounter
        return allEntries().lazy.filter { $0.isFocused && $0.readingState == .backlog }.count
    }

    /// 上限まで枠が空いているか。View 側で「フォーカスする」項目を出すか判定するのに使う。
    func canFocus() -> Bool {
        focusedBacklogCount() < Self.maxFocusedBacklogCount
    }

    /// 積読エントリーをフォーカス指定する。上限超過時は何もしない。
    /// 積読でないエントリーには適用しない（呼び出し側で readingState をチェックする想定）。
    func focus(_ entry: MangaEntry) {
        guard entry.readingState == .backlog else { return }
        guard !entry.isFocused else { return }
        guard canFocus() else { return }
        entry.isFocused = true
        entry.focusedAt = Date()
        saveFocusChange(for: entry)
    }

    /// フォーカス指定を解除する。
    func unfocus(_ entry: MangaEntry) {
        guard entry.isFocused else { return }
        entry.isFocused = false
        entry.focusedAt = nil
        saveFocusChange(for: entry)
    }

    /// フォーカス変更をエントリの所属する ModelContext で確実に保存する。
    /// `refresh()` で `viewModel.modelContext` が差し替わった後でも、UI が保持している
    /// `entry` は元のコンテキストに残っているケースがあるため、両方を save する
    /// （`updateEntry` と同じパターン）。
    private func saveFocusChange(for entry: MangaEntry) {
        if let entryCtx = entry.modelContext, entryCtx !== modelContext {
            do {
                try entryCtx.save()
            } catch {
                print("[MangaViewModel] saveFocusChange entryCtx save failed: \(error)")
                lastError = .save(error)
                return
            }
        }
        save()
    }

    // 注意: アクティビティ・メモ集約は ActivityBuilder に移譲。
    // ここに recentActivity / allActivity / memoEntryCount などを置かないこと（N+1 fetch の温床になる）。
    // メモの更新は updateEntry() に統合済み。

    // MARK: - Comments

    func addComment(_ entry: MangaEntry, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = MangaComment(mangaEntryID: entry.id, content: trimmed)
        modelContext.insert(comment)
        save()
    }

    func updateComment(_ comment: MangaComment, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        comment.content = trimmed
        comment.updatedAt = Date()
        save()
    }

    func deleteComment(_ comment: MangaComment) {
        modelContext.delete(comment)
        save()
    }

    // MARK: - Comment Undo Delete

    /// コメントを削除キューに入れる。entry の queueDelete と同じ「5 秒後に commit / 間に undo 可」仕様。
    func queueDeleteComment(_ comment: MangaComment) {
        pendingDeleteComments.append(comment)
        refreshCounter += 1
        restartCommentDeleteTimer()
    }

    func undoPendingCommentDeletes() {
        commentDeleteTimer?.invalidate()
        commentDeleteTimer = nil
        pendingDeleteComments.removeAll()
        refreshCounter += 1
    }

    func commitPendingCommentDeletes() {
        commentDeleteTimer?.invalidate()
        commentDeleteTimer = nil
        for comment in pendingDeleteComments {
            modelContext.delete(comment)
        }
        pendingDeleteComments.removeAll()
        save()
    }

    private func restartCommentDeleteTimer() {
        commentDeleteTimer?.invalidate()
        commentDeleteTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitPendingCommentDeletes()
            }
        }
    }

    func fetchComments(for entry: MangaEntry) -> [MangaComment] {
        let _ = refreshCounter
        let entryID = entry.id
        let descriptor = FetchDescriptor<MangaComment>(
            predicate: #Predicate { $0.mangaEntryID == entryID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let pendingIDs = Set(pendingDeleteComments.map(\.id))
        return modelContext.fetchLogged(descriptor).filter { !pendingIDs.contains($0.id) }
    }

    func allComments() -> [MangaComment] {
        invalidateCacheIfStale()
        if let cached = cachedComments { return cached }
        let descriptor = FetchDescriptor<MangaComment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let pendingIDs = Set(pendingDeleteComments.map(\.id))
        let result = modelContext.fetchLogged(descriptor).filter { !pendingIDs.contains($0.id) }
        cachedComments = result
        return result
    }

    // MARK: - Links

    func addLink(_ entry: MangaEntry, linkType: LinkType, title: String, url: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        let existingLinks = fetchLinks(for: entry)
        let nextOrder = (existingLinks.map(\.sortOrder).max() ?? -1) + 1
        let link = MangaLink(
            mangaEntryID: entry.id,
            linkType: linkType,
            title: trimmedTitle,
            url: trimmedURL,
            sortOrder: nextOrder
        )
        modelContext.insert(link)
        save()
    }

    func updateLink(_ link: MangaLink, linkType: LinkType, title: String, url: String) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        link.linkType = linkType
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        link.url = trimmedURL
        link.updatedAt = Date()
        save()
    }

    func deleteLink(_ link: MangaLink) {
        modelContext.delete(link)
        save()
        refreshCounter += 1
    }

    func fetchLinks(for entry: MangaEntry) -> [MangaLink] {
        let _ = refreshCounter
        let entryID = entry.id
        let descriptor = FetchDescriptor<MangaLink>(
            predicate: #Predicate { $0.mangaEntryID == entryID },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return modelContext.fetchLogged(descriptor)
    }

    func allLinks() -> [MangaLink] {
        let descriptor = FetchDescriptor<MangaLink>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return modelContext.fetchLogged(descriptor)
    }

    func moveLinks(for entry: MangaEntry, from source: IndexSet, to destination: Int) {
        var links = fetchLinks(for: entry)
        links.move(fromOffsets: source, toOffset: destination)
        for (index, link) in links.enumerated() {
            link.sortOrder = index
        }
        save()
        refreshCounter += 1
    }

    /// タイムラインのアクティビティドットや日別集計に使う全 ReadingActivity。
    /// ReadingStatsProvider.fetchActivityCounts は日付→件数のマップで情報が
    /// 抜けるため、個々の record が欲しい用途はこちらを使う。
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

    /// refreshCounter が変わっていたらキャッシュを破棄。
    /// これにより同一 render 内の複数呼び出しは 1 回の fetch で済む。
    private func invalidateCacheIfStale() {
        let _ = refreshCounter
        if cacheVersion != refreshCounter {
            cacheVersion = refreshCounter
            cachedEntries = nil
            cachedComments = nil
            cachedActivities = nil
            cachedPublisherIcons = nil
        }
    }

    func unreadCount(for day: DayOfWeek) -> Int {
        unreadEntries(for: day).count
    }

    var stats: ReadingStatsProvider {
        ReadingStatsProvider(modelContext: modelContext)
    }

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

    private func save() {
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
