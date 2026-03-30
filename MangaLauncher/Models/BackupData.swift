import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let entries: [BackupEntry]

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
        let isOnHiatus: Bool?

        init(id: UUID, name: String, url: String, dayOfWeekRawValue: Int, sortOrder: Int, iconColor: String, publisher: String, imageData: Data?, lastReadDate: Date? = nil, updateIntervalWeeks: Int = 1, nextExpectedUpdate: Date? = nil, isOnHiatus: Bool = false) {
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
            self.isOnHiatus = isOnHiatus
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
            isOnHiatus = try container.decodeIfPresent(Bool.self, forKey: .isOnHiatus)
        }
    }

    static func from(_ entries: [MangaEntry]) -> BackupData {
        BackupData(
            version: 3,
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
                    isOnHiatus: $0.isOnHiatus
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
