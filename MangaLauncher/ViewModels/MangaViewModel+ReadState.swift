import Foundation
import SwiftData

// MARK: - Read State, Focused Backlog, Soft Delete

extension MangaViewModel {

    // MARK: State Changes

    /// 掲載状況の付け替え
    func setPublicationStatus(_ entry: MangaEntry, to status: PublicationStatus) {
        entry.publicationStatus = status
        saveEntryChange(for: entry)
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
        saveEntryChange(for: entry)
    }

    /// パーソナル評価を設定する。nil で評価解除。
    func setPersonalRating(_ entry: MangaEntry, to rating: Int?) {
        entry.personalRating = MangaEntry.clampedRating(rating)
        saveEntryChange(for: entry)
    }

    /// 非表示フラグの切り替え
    func setHidden(_ entry: MangaEntry, isHidden: Bool) {
        entry.isHidden = isHidden
        if isHidden {
            hiddenIDs.insert(entry.id)
        } else {
            hiddenIDs.remove(entry.id)
        }
        saveEntryChange(for: entry)
    }

    // MARK: Mark Read / Unread

    func markAsRead(_ entry: MangaEntry) {
        entry.lastReadDate = Date()
        if !entry.isOneShot {
            entry.advanceToNextUpdate()
        }
        // 同日・同エントリのアクティビティが既に存在する場合は再 insert しない。
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
            // entry と同じコンテキストに挿入（refresh() 後の不整合を防ぐ）
            (entry.modelContext ?? modelContext).insert(activity)
        }
        if entry.isOneShot {
            entry.readingState = .archived
        }
        saveEntryChange(for: entry)
    }

    /// 複数エントリを一括既読にする。save() を1回にまとめてパフォーマンスを最適化。
    /// CatchUp の「全部既読」で使用。
    func markEntriesAsRead(_ entries: [MangaEntry]) {
        guard !entries.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: Date())

        // 今日の既存アクティビティを一括取得（N回 fetch → 1回に最適化）
        let entryIDs = entries.map(\.id)
        let existingDescriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.date == today }
        )
        let existingActivityEntryIDs = Set(
            modelContext.fetchLogged(existingDescriptor)
                .filter { entryIDs.contains($0.mangaEntryID) }
                .map(\.mangaEntryID)
        )

        for entry in entries {
            let ctx = entry.modelContext ?? modelContext
            entry.lastReadDate = Date()
            if !entry.isOneShot {
                entry.advanceToNextUpdate()
            }
            // 存在チェックと挿入を同じコンテキストで行う
            if !existingActivityEntryIDs.contains(entry.id) {
                let activity = ReadingActivity(
                    date: Date(),
                    mangaName: entry.name,
                    mangaEntryID: entry.id
                )
                ctx.insert(activity)
            }
            if entry.isOneShot {
                entry.readingState = .archived
            }
        }
        // entry が複数コンテキストに跨る可能性に備え、全ユニークコンテキストを保存
        var savedContexts = Set<ObjectIdentifier>()
        for entry in entries {
            guard let entryCtx = entry.modelContext, entryCtx !== modelContext else { continue }
            let ctxID = ObjectIdentifier(entryCtx)
            guard savedContexts.insert(ctxID).inserted else { continue }
            do {
                try entryCtx.save()
            } catch {
                print("[MangaViewModel] markEntriesAsRead entryCtx save failed: \(error)")
                lastError = .save(error)
                return
            }
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
        saveEntryChange(for: entry)
    }

    // MARK: Unread Queries

    func unreadEntries(for day: DayOfWeek) -> [MangaEntry] {
        fetchEntries(for: day).filter { !$0.isRead }
    }

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

    func allUnreadCount() -> Int {
        let _ = refreshCounter
        return allEntries().lazy.filter {
            !$0.isRead
                && $0.readingState == .following
                && $0.publicationStatus == .active
        }.count
    }

    // MARK: Focused Backlog

    /// 同時にフォーカス指定できる積読の上限本数。
    static let maxFocusedBacklogCount = 3

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

    func canFocus() -> Bool {
        focusedBacklogCount() < Self.maxFocusedBacklogCount
    }

    func focus(_ entry: MangaEntry) {
        guard entry.readingState == .backlog else { return }
        guard !entry.isFocused else { return }
        guard canFocus() else { return }
        entry.isFocused = true
        entry.focusedAt = Date()
        saveFocusChange(for: entry)
    }

    func unfocus(_ entry: MangaEntry) {
        guard entry.isFocused else { return }
        entry.isFocused = false
        entry.focusedAt = nil
        saveFocusChange(for: entry)
    }

    private func saveFocusChange(for entry: MangaEntry) {
        saveEntryChange(for: entry)
    }

    // MARK: Soft Delete

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
        return results.filter { currentDeletedIDs.contains($0.id) }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    func hasHiddenDeletedEntries() -> Bool {
        deletedEntries().contains { $0.isHidden }
    }

    func deletedEntryCount() -> Int {
        deletedEntries().count
    }

    func purgeExpiredSoftDeletes() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        let descriptor = FetchDescriptor<MangaEntry>(predicate: #Predicate { $0.deletedAt != nil })
        guard let softDeleted = try? modelContext.fetch(descriptor) else { return }
        let expired = softDeleted.filter { ($0.deletedAt ?? .distantFuture) < cutoff }
        guard !expired.isEmpty else { return }
        for entry in expired {
            permanentlyDeleteWithoutSave(entry)
        }
        save()
    }
}
