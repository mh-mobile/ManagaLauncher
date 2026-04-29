import Foundation
import SwiftData

/// リンクの種類
enum LinkType: Int, Codable, CaseIterable, Identifiable {
    case twitter = 0
    case website = 1
    case pixiv = 2
    case youtube = 3
    case instagram = 4
    case tiktok = 5
    case other = 99

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .twitter: "X (Twitter)"
        case .website: "公式サイト"
        case .pixiv: "pixiv"
        case .youtube: "YouTube"
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .other: "その他"
        }
    }

    var iconName: String {
        switch self {
        case .twitter: "bird"
        case .website: "globe"
        case .pixiv: "paintbrush"
        case .youtube: "play.rectangle"
        case .instagram: "camera"
        case .tiktok: "music.note"
        case .other: "link"
        }
    }

    /// URL 文字列からリンク種別を自動判定する。
    /// 判定できない場合は `.other` を返す。
    static func detect(from urlString: String) -> LinkType {
        let lower = urlString.lowercased()
        if lower.contains("twitter.com") || lower.contains("x.com") { return .twitter }
        if lower.contains("pixiv.net") { return .pixiv }
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("instagram.com") { return .instagram }
        if lower.contains("tiktok.com") { return .tiktok }
        return .other
    }
}

/// マンガ作品に紐付く関連リンク（SNS・公式サイトなど）
@Model
final class MangaLink: Identifiable {
    var id: UUID = UUID()
    var mangaEntryID: UUID = UUID()
    var linkTypeRawValue: Int = 99
    var title: String = ""
    var url: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date?

    @Transient
    var linkType: LinkType {
        get { LinkType(rawValue: linkTypeRawValue) ?? .other }
        set { linkTypeRawValue = newValue.rawValue }
    }

    init(
        mangaEntryID: UUID,
        linkType: LinkType = .other,
        title: String = "",
        url: String,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.mangaEntryID = mangaEntryID
        self.linkTypeRawValue = linkType.rawValue
        self.title = title
        self.url = url
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = nil
    }
}
