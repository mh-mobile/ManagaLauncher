import Foundation
import SwiftData

// MARK: - Startup Migrations & Deduplication

extension MangaViewModel {

    /// 起動後 1 回だけ実行する重い初期化処理。
    /// 初回 active phase で呼ばれることを想定 (アプリ側で onAppear / scenePhase 監視)。
    func runStartupMigrationsIfNeeded() {
        guard !didRunStartupMigrations else { return }
        didRunStartupMigrations = true
        migrateLegacyStateIfNeeded()
        backfillMemoUpdatedAtIfNeeded()
        purgeExpiredSoftDeletes()
        dedupeEntriesIfNeeded()
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

    /// 同じ URL × 同じ曜日 のエントリが複数存在する場合、情報量が最も多い 1 件を残して
    /// 残りを削除する。SwiftData + CloudKit では `@Attribute(.unique)` が使えず、
    /// 端末間の同期不整合等で重複が残ることがある。
    private func dedupeEntriesIfNeeded() {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let active: [MangaEntry]
        do {
            active = try modelContext.fetch(descriptor)
        } catch {
            print("[MangaViewModel] dedupe fetch failed: \(error)")
            lastError = .migration(error)
            return
        }
        guard active.count >= 2 else { return }

        struct DedupeKey: Hashable {
            let url: String
            let day: Int
        }

        let groups = Dictionary(grouping: active) { entry in
            DedupeKey(
                url: entry.url.trimmingCharacters(in: .whitespacesAndNewlines),
                day: entry.dayOfWeekRawValue
            )
        }

        var deletions: [(kept: MangaEntry, losers: [MangaEntry])] = []
        for (key, group) in groups where group.count >= 2 && !key.url.isEmpty {
            let sorted = group.sorted { lhs, rhs in
                let l = Self.dedupeScore(of: lhs)
                let r = Self.dedupeScore(of: rhs)
                if l != r { return l > r }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            guard let kept = sorted.first else { continue }
            let losers = Array(sorted.dropFirst())
            deletions.append((kept: kept, losers: losers))
        }

        guard !deletions.isEmpty else { return }

        let totalToDelete = deletions.reduce(0) { $0 + $1.losers.count }
        print("[MangaViewModel] dedupe: removing \(totalToDelete) duplicate entries across \(deletions.count) groups")
        // 情報は残す側へ統合する。別 UUID の重複 (ユーザー操作由来) は完全削除せず痕跡としてゴミ箱へ送る
        // (同じ作品が残っている間は復元できない。残す側を削除すれば復元できる)。同 UUID の重複 (同期由来の同一レコード) は deletedIDs で残す側まで
        // 隠れてしまうため完全削除する。
        let now = Date()
        for (kept, losers) in deletions {
            for loser in losers {
                Self.merge(loser, into: kept)
                if loser.id == kept.id {
                    modelContext.delete(loser)
                } else {
                    repointRelatedReferences(from: loser.id, to: kept.id)
                    loser.deletedAt = now
                }
            }
        }
        do {
            try modelContext.save()
            reloadHiddenIDs()
            reloadDeletedIDs()
            refreshCounter += 1
        } catch {
            print("[MangaViewModel] dedupe save failed: \(error)")
            lastError = .migration(error)
        }
    }

    /// 重複統合で削除されるエントリの UUID を参照している
    /// ReadingActivity / MangaComment / MangaLink を、残す方の UUID に付け替える。
    private func repointRelatedReferences(from oldID: UUID, to newID: UUID) {
        let activityDescriptor = FetchDescriptor<ReadingActivity>(
            predicate: #Predicate { $0.mangaEntryID == oldID }
        )
        if let activities = try? modelContext.fetch(activityDescriptor) {
            for a in activities { a.mangaEntryID = newID }
        }
        let commentDescriptor = FetchDescriptor<MangaComment>(
            predicate: #Predicate { $0.mangaEntryID == oldID }
        )
        if let comments = try? modelContext.fetch(commentDescriptor) {
            for c in comments { c.mangaEntryID = newID }
        }
        let linkDescriptor = FetchDescriptor<MangaLink>(
            predicate: #Predicate { $0.mangaEntryID == oldID }
        )
        if let links = try? modelContext.fetch(linkDescriptor) {
            for l in links { l.mangaEntryID = newID }
        }
    }

    /// 削除側にしかない情報を残す側へ移す。メモは両方あれば連結する。
    private static func merge(_ loser: MangaEntry, into kept: MangaEntry) {
        if !loser.memo.isEmpty && !kept.memo.contains(loser.memo) {
            kept.memo = kept.memo.isEmpty ? loser.memo : kept.memo + "\n\n" + loser.memo
            kept.memoUpdatedAt = [kept.memoUpdatedAt, loser.memoUpdatedAt].compactMap { $0 }.max()
        }
        kept.personalRating = kept.personalRating ?? loser.personalRating
        kept.currentEpisode = [kept.currentEpisode, loser.currentEpisode].compactMap { $0 }.max()
        kept.latestEpisode = [kept.latestEpisode, loser.latestEpisode].compactMap { $0 }.max()
        kept.episodeLabel = kept.episodeLabel ?? loser.episodeLabel
        kept.lastReadDate = [kept.lastReadDate, loser.lastReadDate].compactMap { $0 }.max()
        if kept.imageData == nil {
            kept.imageData = loser.imageData
        }
    }

    /// 重複グループ内で残す 1 件を決めるためのスコア。値が大きいほど情報量が多い。
    private static func dedupeScore(of entry: MangaEntry) -> Int {
        var s = 0
        if !entry.memo.isEmpty { s += 10 }
        if entry.lastReadDate != nil { s += 5 }
        if entry.isFocused { s += 5 }
        if entry.currentEpisode != nil { s += 3 }
        if entry.personalRating != nil { s += 3 }
        if entry.latestEpisode != nil { s += 2 }
        if entry.imageData != nil { s += 2 }
        if entry.episodeLabel != nil { s += 1 }
        if entry.nextExpectedUpdate != nil { s += 1 }
        return s
    }

    /// memoUpdatedAt 追加前に書かれたメモには nil が入っているので、
    /// 起動時に一度だけ現在時刻でバックフィルする。
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
}
