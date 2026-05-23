import Foundation
import SwiftUI
import SwiftData
import NotificationKit
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Entry CRUD & Reorder

extension MangaViewModel {

    func addEntry(name: String, url: String, days: Set<DayOfWeek>, iconColor: String, publisher: String = "", imageData: Data? = nil, updateIntervalWeeks: Int = 1, nextExpectedUpdate: Date? = nil, publicationStatus: PublicationStatus = .active, readingState: ReadingState = .following, isOneShot: Bool = false, memo: String = "", currentEpisode: Int? = nil, episodeLabel: String? = nil, personalRating: Int? = nil, latestEpisode: Int? = nil) {
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
            entry.personalRating = personalRating.map { max(1, min(5, $0)) }
            entry.latestEpisode = latestEpisode.map { max(1, $0) }
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
        personalRating: Int? = nil,
        latestEpisode: Int? = nil,
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
        entry.personalRating = personalRating.map { max(1, min(5, $0)) }
        entry.latestEpisode = latestEpisode.map { max(1, $0) }

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

    // MARK: - Delete (Queue / Commit / Undo)

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

    // MARK: - Move / Reorder

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
}
