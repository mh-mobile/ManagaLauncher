import Foundation
import SwiftData

// MARK: - Backup Export / Import

extension MangaViewModel {

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
        let metaDescriptor = FetchDescriptor<PublisherMetadata>(sortBy: [SortDescriptor(\.name)])
        let publisherMetadata = modelContext.fetchLogged(metaDescriptor)
        let backup = BackupData.from(entries, activities: activities, comments: comments, links: links, publisherMetadata: publisherMetadata)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    enum ImportOutcome {
        case imported(Int)
        case decodeFailed
        case versionError(Int)
    }

    func importBackupData(_ data: Data) -> ImportOutcome {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupData.self, from: data) else { return .decodeFailed }

        if backup.version > BackupData.currentVersion {
            print("[Backup] version \(backup.version) > currentVersion \(BackupData.currentVersion), rejecting import")
            return .versionError(backup.version)
        }

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
            entry.personalRating = backupEntry.personalRating.map { max(1, min(5, $0)) }
            entry.latestEpisode = backupEntry.latestEpisode.map { max(1, $0) }
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
        return .imported(importedCount)
    }
}
