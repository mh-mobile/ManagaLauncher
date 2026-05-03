import Foundation
import SwiftData

/// 掲載誌名 (`MangaEntry.publisher`) に紐付くメタデータ。
/// 別テーブルにすることで、既存 String カラムに触らず付随情報（アイコン等）を拡張できる。
/// `name` をキーに `MangaEntry.publisher` と論理 join する。
///
/// CloudKit 同期対象。`@Attribute(.unique)` は使わない（既存モデルと統一、CloudKit との
/// 組み合わせで race 時の挙動が不安定になるため）。重複は ViewModel 層で soft de-dup する。
@Model
final class PublisherMetadata: Identifiable {
    var id: UUID = UUID()

    /// 掲載誌名。`MangaEntry.publisher` と完全一致でジョインする。
    var name: String = ""

    /// アイコン画像（JPEG, 256x256, 1:1 にクロップ済みを期待）。
    /// SQLite を太らせないため externalStorage で外部保存。
    @Attribute(.externalStorage) var iconData: Data?

    /// アイコン取得元の URL（ファビコンとして取得した場合の参照、再取得用）。
    var sourceURL: String?

    /// アイコン更新日時。重複 record の優先度判定にも使う。
    var updatedAt: Date?

    init(name: String, iconData: Data? = nil, sourceURL: String? = nil) {
        self.id = UUID()
        self.name = name
        self.iconData = iconData
        self.sourceURL = sourceURL
        self.updatedAt = iconData == nil ? nil : Date()
    }
}
