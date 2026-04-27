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
        let currentDeletedIDs = deletedIDs
        var seenIDs = Set<UUID>()
        let result = modelContext.fetchLogged(descriptor).filter { entry in
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
        let backup = BackupData.from(entries, activities: activities, comments: comments)
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
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
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
