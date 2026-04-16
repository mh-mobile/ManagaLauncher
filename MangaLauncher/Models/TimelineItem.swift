import Foundation

/// 1 日のアクティビティタイムラインを構成する単一アイテム。
/// コメント / メモ更新 / 読んだ記録 を統一的に並べるための sum type。
enum TimelineItem: Identifiable {
    case comment(MangaComment, MangaEntry)
    case memo(MangaEntry)
    case read(ReadingActivity, MangaEntry?)

    var id: String {
        switch self {
        case .comment(let comment, _): return "c-\(comment.id.uuidString)"
        case .memo(let entry): return "m-\(entry.id.uuidString)"
        case .read(let activity, _): return "r-\(activity.id.uuidString)"
        }
    }

    /// タイムライン上の時刻。秒単位で並べるときに使う。
    /// 旧 ReadingActivity は timestamp が nil なので startOfDay にフォールバック。
    /// 正確な時刻かどうかは `hasPreciseTime` で判定する。
    var timestamp: Date {
        switch self {
        case .comment(let comment, _): return comment.updatedAt ?? comment.createdAt
        case .memo(let entry): return entry.memoUpdatedAt ?? .distantPast
        case .read(let activity, _): return activity.timestamp ?? activity.date
        }
    }

    /// timestamp が秒単位の情報を持つか。旧 ReadingActivity (timestamp == nil) は false。
    var hasPreciseTime: Bool {
        switch self {
        case .comment, .memo: return true
        case .read(let activity, _): return activity.timestamp != nil
        }
    }

    /// 関連エントリ。読んだ記録で entry が見つからなかった場合のみ nil。
    var entry: MangaEntry? {
        switch self {
        case .comment(_, let entry): return entry
        case .memo(let entry): return entry
        case .read(_, let entry): return entry
        }
    }

    var mangaName: String {
        switch self {
        case .comment(_, let entry): return entry.name
        case .memo(let entry): return entry.name
        case .read(let activity, let entry): return entry?.name ?? activity.mangaName
        }
    }
}

// MARK: - Filter

/// タイムラインの種別フィルタ。チップ UI のソース。
enum TimelineFilter: String, CaseIterable, Hashable, Identifiable {
    case all, comment, memo, read

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "すべて"
        case .comment: "コメント"
        case .memo: "メモ"
        case .read: "既読"
        }
    }

    var iconName: String {
        switch self {
        case .all: "list.bullet"
        case .comment: "bubble.left.fill"
        case .memo: "pencil"
        case .read: "checkmark"
        }
    }

    func apply(to items: [TimelineItem]) -> [TimelineItem] {
        switch self {
        case .all:
            return items
        case .comment:
            return items.filter { if case .comment = $0 { true } else { false } }
        case .memo:
            return items.filter { if case .memo = $0 { true } else { false } }
        case .read:
            return items.filter { if case .read = $0 { true } else { false } }
        }
    }
}

/// TimelineItem を構築する純関数群。
/// 呼び出し側は必要なデータを一度 fetch して渡す（N+1 fetch を避ける）。
enum TimelineBuilder {
    /// 指定日のアクティビティを時系列降順で返す。
    static func items(
        for date: Date,
        entries: [MangaEntry],
        comments: [MangaComment],
        activities: [ReadingActivity]
    ) -> [TimelineItem] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })

        var items: [TimelineItem] = []

        // Comments
        for comment in comments {
            guard comment.createdAt >= startOfDay, comment.createdAt < endOfDay else { continue }
            guard let entry = entriesByID[comment.mangaEntryID] else { continue }
            items.append(.comment(comment, entry))
        }

        // Memo updates
        for entry in entries {
            guard let updated = entry.memoUpdatedAt,
                  updated >= startOfDay, updated < endOfDay,
                  !entry.memo.isEmpty else { continue }
            items.append(.memo(entry))
        }

        // Reading activities
        for activity in activities {
            guard activity.date >= startOfDay, activity.date < endOfDay else { continue }
            items.append(.read(activity, entriesByID[activity.mangaEntryID]))
        }

        // 昇順 (朝→夜) で 1 日の流れを読めるようにする
        return items.sorted { $0.timestamp < $1.timestamp }
    }

    /// アクティビティがあった日 (startOfDay) の集合。
    /// WeekStripView などでドット表示に使う。
    /// items() と同じ可視条件で判定し、孤児コメント (entry 不在) はカウントしない。
    static func activeDays(
        entries: [MangaEntry],
        comments: [MangaComment],
        activities: [ReadingActivity]
    ) -> Set<Date> {
        let calendar = Calendar.current
        let entryIDs = Set(entries.map(\.id))
        var days = Set<Date>()
        for comment in comments where entryIDs.contains(comment.mangaEntryID) {
            days.insert(calendar.startOfDay(for: comment.createdAt))
        }
        for entry in entries {
            if let updated = entry.memoUpdatedAt, !entry.memo.isEmpty {
                days.insert(calendar.startOfDay(for: updated))
            }
        }
        for activity in activities {
            days.insert(calendar.startOfDay(for: activity.date))
        }
        return days
    }
}
