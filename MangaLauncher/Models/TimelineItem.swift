import Foundation

/// TimelineItem のタイプを表す軽量タグ。Swift Charts での集計など
/// enum 本体の associated value 無しで扱いたい場面で使う。
enum TimelineItemKind: String, CaseIterable, Identifiable {
    case comment, memo, read

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comment: "コメント"
        case .memo: "メモ"
        case .read: "既読"
        }
    }
}

/// 1 日のアクティビティタイムラインを構成する単一アイテム。
/// コメント / メモ更新 / 読んだ記録 を統一的に並べるための sum type。
enum TimelineItem: Identifiable {
    case comment(MangaComment, MangaEntry)
    case memo(MangaEntry)
    case read(ReadingActivity, MangaEntry?)

    var kind: TimelineItemKind {
        switch self {
        case .comment: .comment
        case .memo: .memo
        case .read: .read
        }
    }

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

    /// フィルタが単一種別を指す場合の TimelineItemKind。.all のとき nil。
    /// チャートのフィルタ連動などで使う。
    var kind: TimelineItemKind? {
        switch self {
        case .all: nil
        case .comment: .comment
        case .memo: .memo
        case .read: .read
        }
    }

    func apply(to items: [TimelineItem]) -> [TimelineItem] {
        guard let kind else { return items }
        return items.filter { $0.kind == kind }
    }
}

// MARK: - Chart granularity

/// タイムラインチャートの期間粒度。週 (7 日) / 月 (30 日前後)。
enum TimelineChartGranularity: String, CaseIterable, Hashable, Identifiable {
    case week, month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .week: "週"
        case .month: "月"
        }
    }

    /// 指定日を含む期間の日付配列。月曜はじまりの週 / 月の 1 日はじまりの月。
    func days(containing date: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        switch self {
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let start = calendar.date(from: components) ?? date
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let start = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
            return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
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

        let entriesByID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

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

    /// 指定した日付集合の、タイプ別件数を返す。Swift Charts の棒グラフ用。
    /// 日付 × 種別 の全組合せで 0 件もエントリを作ることで、グラフが
    /// 日付方向に途切れないようにする。
    static func dailyCounts(
        days: [Date],
        entries: [MangaEntry],
        comments: [MangaComment],
        activities: [ReadingActivity]
    ) -> [TimelineDailyCount] {
        days.flatMap { day in
            let items = items(for: day, entries: entries, comments: comments, activities: activities)
            let byKind = Dictionary(grouping: items, by: \.kind).mapValues(\.count)
            return TimelineItemKind.allCases.map { kind in
                TimelineDailyCount(date: day, kind: kind, count: byKind[kind] ?? 0)
            }
        }
    }
}

/// Swift Charts に渡す集計単位。
struct TimelineDailyCount: Identifiable, Hashable {
    let date: Date
    let kind: TimelineItemKind
    let count: Int

    var id: String { "\(date.timeIntervalSince1970)-\(kind.rawValue)" }
}
