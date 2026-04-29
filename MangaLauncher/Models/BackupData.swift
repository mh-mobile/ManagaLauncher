import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let entries: [BackupEntry]
    let activities: [BackupActivity]?
    let comments: [BackupComment]?
    let links: [BackupLink]?

    struct BackupActivity: Codable {
        let id: UUID
        let date: Date
        let mangaName: String
        let mangaEntryID: UUID
        // v12+
        let timestamp: Date?
        let episodeNumber: Int?
        let episodeLabel: String?

        init(id: UUID, date: Date, mangaName: String, mangaEntryID: UUID, timestamp: Date? = nil, episodeNumber: Int? = nil, episodeLabel: String? = nil) {
            self.id = id
            self.date = date
            self.mangaName = mangaName
            self.mangaEntryID = mangaEntryID
            self.timestamp = timestamp
            self.episodeNumber = episodeNumber
            self.episodeLabel = episodeLabel
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            date = try container.decode(Date.self, forKey: .date)
            mangaName = try container.decode(String.self, forKey: .mangaName)
            mangaEntryID = try container.decode(UUID.self, forKey: .mangaEntryID)
            timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
            episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
            episodeLabel = try container.decodeIfPresent(String.self, forKey: .episodeLabel)
        }
    }

    struct BackupComment: Codable {
        let id: UUID
        let mangaEntryID: UUID
        let content: String
        let createdAt: Date
        let updatedAt: Date?
    }

    struct BackupLink: Codable {
        let id: UUID
        let mangaEntryID: UUID
        let linkTypeRawValue: Int
        let title: String
        let url: String
        let sortOrder: Int
        let createdAt: Date
        let updatedAt: Date?
    }

    struct BackupEntry: Codable {
        let id: UUID
        let name: String
        let url: String
        let dayOfWeekRawValue: Int
        let sortOrder: Int
        let iconColor: String
        let publisher: String
        let imageData: Data?
        let lastReadDate: Date?
        let updateIntervalWeeks: Int
        let nextExpectedUpdate: Date?
        let isOneShot: Bool?
        // New schema (v6+)
        let publicationStatusRawValue: Int?
        let readingStateRawValue: Int?
        // v7+
        let memo: String?
        // v8+
        let memoUpdatedAt: Date?
        // v9+
        let currentEpisode: Int?
        // v10+
        let episodeLabel: String?
        // v11+
        let isHidden: Bool?
        // v13+
        let deletedAt: Date?
        // Legacy fields (kept for backward-compat with v5 backups)
        let isOnHiatus: Bool?
        let isCompleted: Bool?
        let isBacklog: Bool?

        init(id: UUID, name: String, url: String, dayOfWeekRawValue: Int, sortOrder: Int, iconColor: String, publisher: String, imageData: Data?, lastReadDate: Date? = nil, updateIntervalWeeks: Int = 1, nextExpectedUpdate: Date? = nil, isOneShot: Bool = false, publicationStatusRawValue: Int = 0, readingStateRawValue: Int = 0, memo: String = "", memoUpdatedAt: Date? = nil, currentEpisode: Int? = nil, episodeLabel: String? = nil, isHidden: Bool = false, deletedAt: Date? = nil) {
            self.id = id
            self.name = name
            self.url = url
            self.dayOfWeekRawValue = dayOfWeekRawValue
            self.sortOrder = sortOrder
            self.iconColor = iconColor
            self.publisher = publisher
            self.imageData = imageData
            self.lastReadDate = lastReadDate
            self.updateIntervalWeeks = updateIntervalWeeks
            self.nextExpectedUpdate = nextExpectedUpdate
            self.isOneShot = isOneShot
            self.publicationStatusRawValue = publicationStatusRawValue
            self.readingStateRawValue = readingStateRawValue
            self.memo = memo
            self.memoUpdatedAt = memoUpdatedAt
            self.currentEpisode = currentEpisode
            self.episodeLabel = episodeLabel
            self.isHidden = isHidden
            self.deletedAt = deletedAt
            self.isOnHiatus = nil
            self.isCompleted = nil
            self.isBacklog = nil
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            url = try container.decode(String.self, forKey: .url)
            dayOfWeekRawValue = try container.decode(Int.self, forKey: .dayOfWeekRawValue)
            sortOrder = try container.decode(Int.self, forKey: .sortOrder)
            iconColor = try container.decode(String.self, forKey: .iconColor)
            publisher = try container.decode(String.self, forKey: .publisher)
            imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
            lastReadDate = try container.decodeIfPresent(Date.self, forKey: .lastReadDate)
            updateIntervalWeeks = try container.decodeIfPresent(Int.self, forKey: .updateIntervalWeeks) ?? 1
            nextExpectedUpdate = try container.decodeIfPresent(Date.self, forKey: .nextExpectedUpdate)
            isOneShot = try container.decodeIfPresent(Bool.self, forKey: .isOneShot)
            publicationStatusRawValue = try container.decodeIfPresent(Int.self, forKey: .publicationStatusRawValue)
            readingStateRawValue = try container.decodeIfPresent(Int.self, forKey: .readingStateRawValue)
            memo = try container.decodeIfPresent(String.self, forKey: .memo)
            memoUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .memoUpdatedAt)
            currentEpisode = try container.decodeIfPresent(Int.self, forKey: .currentEpisode)
            episodeLabel = try container.decodeIfPresent(String.self, forKey: .episodeLabel)
            isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden)
            deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
            isOnHiatus = try container.decodeIfPresent(Bool.self, forKey: .isOnHiatus)
            isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
            isBacklog = try container.decodeIfPresent(Bool.self, forKey: .isBacklog)
        }
    }

    static func from(_ entries: [MangaEntry], activities: [ReadingActivity] = [], comments: [MangaComment] = [], links: [MangaLink] = []) -> BackupData {
        BackupData(
            version: 14,
            exportDate: Date(),
            entries: entries.map {
                BackupEntry(
                    id: $0.id,
                    name: $0.name,
                    url: $0.url,
                    dayOfWeekRawValue: $0.dayOfWeekRawValue,
                    sortOrder: $0.sortOrder,
                    iconColor: $0.iconColor,
                    publisher: $0.publisher,
                    imageData: $0.imageData,
                    lastReadDate: $0.lastReadDate,
                    updateIntervalWeeks: $0.updateIntervalWeeks,
                    nextExpectedUpdate: $0.nextExpectedUpdate,
                    isOneShot: $0.isOneShot,
                    publicationStatusRawValue: $0.publicationStatusRawValue,
                    readingStateRawValue: $0.readingStateRawValue,
                    memo: $0.memo,
                    memoUpdatedAt: $0.memoUpdatedAt,
                    currentEpisode: $0.currentEpisode,
                    episodeLabel: $0.episodeLabel,
                    isHidden: $0.isHidden
                )
            },
            activities: activities.map {
                BackupActivity(
                    id: $0.id,
                    date: $0.date,
                    mangaName: $0.mangaName,
                    mangaEntryID: $0.mangaEntryID,
                    timestamp: $0.timestamp,
                    episodeNumber: $0.episodeNumber,
                    episodeLabel: $0.episodeLabel
                )
            },
            comments: comments.map {
                BackupComment(
                    id: $0.id,
                    mangaEntryID: $0.mangaEntryID,
                    content: $0.content,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            links: links.map {
                BackupLink(
                    id: $0.id,
                    mangaEntryID: $0.mangaEntryID,
                    linkTypeRawValue: $0.linkTypeRawValue,
                    title: $0.title,
                    url: $0.url,
                    sortOrder: $0.sortOrder,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            }
        )
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
