import Foundation
import SwiftData

@Model
final class ReadingActivity {
    var id: UUID = UUID()
    var date: Date = Date()
    var mangaName: String = ""
    var mangaEntryID: UUID = UUID()

    init(date: Date, mangaName: String, mangaEntryID: UUID) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.mangaName = mangaName
        self.mangaEntryID = mangaEntryID
    }
}
