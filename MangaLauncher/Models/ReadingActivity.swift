import Foundation
import SwiftData

@Model
final class ReadingActivity {
    var id: UUID = UUID()
    /// 日単位に正規化された日付。heatmap の集計や同日重複 insert 防止に使う。
    var date: Date = Date()
    /// 秒単位のタイムスタンプ。タイムラインで時刻を表示するのに使う。
    /// 旧データは nil。新規 insert では date 引数の full timestamp を保持する。
    var timestamp: Date?
    var mangaName: String = ""
    var mangaEntryID: UUID = UUID()
    var episodeNumber: Int?

    init(date: Date, mangaName: String, mangaEntryID: UUID, episodeNumber: Int? = nil) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.timestamp = date
        self.mangaName = mangaName
        self.mangaEntryID = mangaEntryID
        self.episodeNumber = episodeNumber
    }
}
