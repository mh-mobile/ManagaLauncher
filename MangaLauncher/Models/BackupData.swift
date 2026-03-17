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
    }

    static func from(_ entries: [MangaEntry]) -> BackupData {
        BackupData(
            version: 1,
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
                    imageData: $0.imageData
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
