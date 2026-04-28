import Foundation

/// ライブラリの「最近のメモ・コメント」セクションで扱う統合アイテム
enum ActivityItem: Identifiable {
    case memo(MangaEntry)
    case comment(MangaComment, MangaEntry)

    var id: String {
        switch self {
        case .memo(let entry): return "m-\(entry.id.uuidString)"
        case .comment(let comment, _): return "c-\(comment.id.uuidString)"
        }
    }

    var timestamp: Date {
        switch self {
        case .memo(let entry): return entry.memoUpdatedAt ?? .distantPast
        case .comment(let comment, _): return comment.createdAt
        }
    }

    var entry: MangaEntry {
        switch self {
        case .memo(let entry): return entry
        case .comment(_, let entry): return entry
        }
    }
}

/// すでに fetch 済みの entries / comments からアクティビティを構築する純関数群。
/// View 側で同じ allEntries() を何度も呼ばないようにするための集約点。
enum ActivityBuilder {
    /// 「最近のメモ・コメント」の上位 N 件
    static func recent(entries: [MangaEntry], comments: [MangaComment], limit: Int) -> [ActivityItem] {
        merged(entries: entries, comments: comments)
            .prefix(limit)
            .map { $0 }
    }

    /// 全アクティビティ（時系列降順）
    static func all(entries: [MangaEntry], comments: [MangaComment]) -> [ActivityItem] {
        merged(entries: entries, comments: comments)
    }

    /// メモ持ちエントリ + コメントの総数
    static func totalCount(entries: [MangaEntry], comments: [MangaComment]) -> Int {
        entries.filter { !$0.memo.isEmpty }.count + comments.count
    }

    private static func merged(entries: [MangaEntry], comments: [MangaComment]) -> [ActivityItem] {
        let entriesByID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var items: [ActivityItem] = entries
            .filter { !$0.memo.isEmpty }
            .map { .memo($0) }
        for comment in comments {
            guard let entry = entriesByID[comment.mangaEntryID] else { continue }
            items.append(.comment(comment, entry))
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }
}
