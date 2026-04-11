import SwiftUI

/// ライブラリ画面の各セクションを表すデータ構造
struct LibrarySection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let iconColor: Color?
    let entries: [MangaEntry]
    let totalCount: Int
    let seeAll: LibraryDestination?

    init(title: String, icon: String?, iconColor: Color? = nil, entries: [MangaEntry], totalCount: Int? = nil, seeAll: LibraryDestination? = nil) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.entries = entries
        self.totalCount = totalCount ?? entries.count
        self.seeAll = seeAll
    }
}

/// ライブラリ画面内の navigationDestination 用の値型
enum LibraryDestination: Hashable {
    case allActivity
    case allPublishers
}
