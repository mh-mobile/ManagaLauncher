import Foundation
import SwiftData

/// マンガに紐付くタイムスタンプ付きコメント（投稿型）
@Model
final class MangaComment {
    var id: UUID = UUID()
    var mangaEntryID: UUID = UUID()
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date?

    init(mangaEntryID: UUID, content: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.mangaEntryID = mangaEntryID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = nil
    }
}
