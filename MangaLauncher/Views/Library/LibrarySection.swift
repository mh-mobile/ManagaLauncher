import SwiftUI

/// ライブラリ画面の各セクションを表すデータ構造
struct LibrarySection: Identifiable {
    /// セクションを一意に識別する stable ID（既定はタイトル）。
    /// 再描画ごとに新しい UUID を生成すると ForEach/LazyVStack がセクションを
    /// tear down してスクロール位置が失われるので、タイトルベースで固定する。
    /// ユーザー入力の名前 (掲載誌・カラーラベル) は固定セクション名や互いと衝突しうるので種類別の ID を渡す。
    let id: String
    let title: String
    let icon: String?
    let iconColor: Color?
    let entries: [MangaEntry]
    let totalCount: Int
    let seeAll: LibraryDestination?

    init(id: String? = nil, title: String, icon: String?, iconColor: Color? = nil, entries: [MangaEntry], totalCount: Int? = nil, seeAll: LibraryDestination? = nil) {
        self.id = id ?? title
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
    case timeline
    case hiddenEntries
    case recentlyDeleted
}
