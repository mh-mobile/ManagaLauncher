import Foundation
import Observation
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
    var pendingDeleteEntries: [MangaEntry] = []
    private var deleteTimer: Timer?

    private(set) var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        migrateLegacyStateIfNeeded()
        backfillMemoUpdatedAtIfNeeded()
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
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let results = modelContext.fetchLogged(descriptor)
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        var seenIDs = Set<UUID>()
        return results.filter { entry in
            guard !pendingIDs.contains(entry.id) else { return false }
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

    func addEntry(name: String, url: String, days: Set<DayOfWeek>, iconColor: String, publisher: String = "", imageData: Data? = nil, updateIntervalWeeks: Int = 1, nextExpectedUpdate: Date? = nil, publicationStatus: PublicationStatus = .active, readingState: ReadingState = .following, isOneShot: Bool = false, memo: String = "") {
        for day in days {
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
        memo: String
    ) {
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
        save()
    }

    func publishers(for day: DayOfWeek) -> [String] {
        let entries = fetchEntries(for: day)
        return Set(entries.map(\.publisher)).filter { !$0.isEmpty }.sorted()
    }

    func allEntries() -> [MangaEntry] {
        let _ = refreshCounter
        let descriptor = FetchDescriptor<MangaEntry>(
            sortBy: [SortDescriptor(\.lastReadDate, order: .reverse), SortDescriptor(\.name)]
        )
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        var seenIDs = Set<UUID>()
        return modelContext.fetchLogged(descriptor).filter { entry in
            guard !pendingIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }
    }

    func allPublishers() -> [String] {
        let descriptor = FetchDescriptor<MangaEntry>()
        let entries = modelContext.fetchLogged(descriptor)
        let publishers = Set(entries.map(\.publisher)).filter { !$0.isEmpty }
        return publishers.sorted()
    }

    func deleteEntry(_ entry: MangaEntry) {
        modelContext.delete(entry)
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
            modelContext.delete(entry)
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
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastStreakShownDate)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.shownMilestones)
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
        let descriptor = FetchDescriptor<MangaEntry>()
        let results = modelContext.fetchLogged(descriptor)
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        var seenIDs = Set<UUID>()
        return results.filter { entry in
            guard !pendingIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }.count
    }

    func exportBackupData() -> Data? {
        let descriptor = FetchDescriptor<MangaEntry>(sortBy: [SortDescriptor(\.dayOfWeekRawValue), SortDescriptor(\.sortOrder)])
        let entries = modelContext.fetchLogged(descriptor)
        guard !entries.isEmpty else { return nil }
        let activityDescriptor = FetchDescriptor<ReadingActivity>(sortBy: [SortDescriptor(\.date)])
        let activities = modelContext.fetchLogged(activityDescriptor)
        let commentDescriptor = FetchDescriptor<MangaComment>(sortBy: [SortDescriptor(\.createdAt)])
        let comments = modelContext.fetchLogged(commentDescriptor)
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
                    mangaEntryID: backupActivity.mangaEntryID
                )
                activity.id = backupActivity.id
                modelContext.insert(activity)
                importedCount += 1
            }
        }
        if importedCount > 0 { save() }
        return importedCount
    }

    func findEntry(by id: UUID) -> MangaEntry? {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return modelContext.fetchLogged(descriptor).first
    }

    func findEntries(by ids: Set<UUID>) -> [UUID: MangaEntry] {
        let descriptor = FetchDescriptor<MangaEntry>()
        let entries = modelContext.fetchLogged(descriptor)
        var result: [UUID: MangaEntry] = [:]
        for entry in entries where ids.contains(entry.id) {
            result[entry.id] = entry
        }
        return result
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

    func fetchComments(for entry: MangaEntry) -> [MangaComment] {
        let _ = refreshCounter
        let entryID = entry.id
        let descriptor = FetchDescriptor<MangaComment>(
            predicate: #Predicate { $0.mangaEntryID == entryID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return modelContext.fetchLogged(descriptor)
    }

    func allComments() -> [MangaComment] {
        let _ = refreshCounter
        let descriptor = FetchDescriptor<MangaComment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return modelContext.fetchLogged(descriptor)
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
        refreshCounter += 1
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("[MangaViewModel] save failed: \(error)")
        }
        refreshCounter += 1
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        BadgeManager.updateBadge(unreadCount: unreadCount(for: .today))
        rescheduleNotifications()
    }
}
