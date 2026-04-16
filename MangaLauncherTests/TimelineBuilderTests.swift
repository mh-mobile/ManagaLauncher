//
//  TimelineBuilderTests.swift
//  MangaLauncherTests
//
//  純関数群の回帰テスト。Xcode でテストターゲットを設定すれば有効化される。
//

import Testing
import Foundation
@testable import MangaLauncher

@Suite("TimelineBuilder")
struct TimelineBuilderTests {

    // MARK: - Helpers

    private func makeEntry(id: UUID = UUID(), name: String = "test", memo: String = "", memoUpdatedAt: Date? = nil) -> MangaEntry {
        let entry = MangaEntry(name: name)
        entry.id = id
        entry.memo = memo
        entry.memoUpdatedAt = memoUpdatedAt
        return entry
    }

    private func makeComment(entryID: UUID, createdAt: Date) -> MangaComment {
        let c = MangaComment(mangaEntryID: entryID, content: "x", createdAt: createdAt)
        c.id = UUID()
        return c
    }

    private func makeActivity(entryID: UUID, date: Date, timestamp: Date? = nil) -> ReadingActivity {
        let a = ReadingActivity(date: date, mangaName: "x", mangaEntryID: entryID)
        a.timestamp = timestamp ?? date
        return a
    }

    private let calendar = Calendar.current

    // MARK: - items(for:)

    @Test("指定日の範囲外のアイテムは除外される")
    func itemsFiltersByDate() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entry = makeEntry(memo: "m", memoUpdatedAt: today.addingTimeInterval(3600))
        let oldComment = makeComment(entryID: entry.id, createdAt: yesterday.addingTimeInterval(3600))
        let todayComment = makeComment(entryID: entry.id, createdAt: today.addingTimeInterval(7200))

        let items = TimelineBuilder.items(
            for: today,
            entries: [entry],
            comments: [oldComment, todayComment],
            activities: []
        )

        #expect(items.count == 2) // memo + todayComment
        #expect(!items.contains { $0.id == "c-\(oldComment.id.uuidString)" })
    }

    @Test("孤児コメント (entry 不在) は items に出ない")
    func itemsIgnoresOrphanComments() {
        let today = calendar.startOfDay(for: Date())
        let orphan = makeComment(entryID: UUID(), createdAt: today.addingTimeInterval(100))

        let items = TimelineBuilder.items(
            for: today,
            entries: [],
            comments: [orphan],
            activities: []
        )

        #expect(items.isEmpty)
    }

    @Test("結果は時系列昇順 (朝→夜)")
    func itemsSortedAscending() {
        let today = calendar.startOfDay(for: Date())
        let entry = makeEntry()
        let c1 = makeComment(entryID: entry.id, createdAt: today.addingTimeInterval(3600))  // 01:00
        let c2 = makeComment(entryID: entry.id, createdAt: today.addingTimeInterval(7200))  // 02:00
        let c3 = makeComment(entryID: entry.id, createdAt: today.addingTimeInterval(18000)) // 05:00

        let items = TimelineBuilder.items(
            for: today,
            entries: [entry],
            comments: [c3, c1, c2], // 逆順で渡す
            activities: []
        )

        #expect(items.map(\.timestamp) == [c1.createdAt, c2.createdAt, c3.createdAt])
    }

    // MARK: - activeDays

    @Test("活動があった日だけが含まれる (孤児コメントは除外)")
    func activeDaysExcludesOrphans() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entry = makeEntry(memo: "m", memoUpdatedAt: today)
        let validComment = makeComment(entryID: entry.id, createdAt: yesterday)
        let orphan = makeComment(entryID: UUID(), createdAt: yesterday)

        let days = TimelineBuilder.activeDays(
            entries: [entry],
            comments: [validComment, orphan],
            activities: []
        )

        #expect(days.contains(today))
        #expect(days.contains(yesterday))
        #expect(days.count == 2)
    }

    // MARK: - dailyCounts

    @Test("dailyCounts は日×種別で 0 件も含む")
    func dailyCountsIncludesZeros() {
        let day1 = calendar.startOfDay(for: Date())
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let entry = makeEntry()
        let comment = makeComment(entryID: entry.id, createdAt: day1.addingTimeInterval(3600))

        let counts = TimelineBuilder.dailyCounts(
            days: [day1, day2],
            entries: [entry],
            comments: [comment],
            activities: []
        )

        // 2 日 × 3 種別 = 6 エントリ
        #expect(counts.count == 6)
        let day1Comment = counts.first { $0.date == day1 && $0.kind == .comment }
        #expect(day1Comment?.count == 1)
        let day2Comment = counts.first { $0.date == day2 && $0.kind == .comment }
        #expect(day2Comment?.count == 0)
    }
}

@Suite("TimelineFilter")
struct TimelineFilterTests {

    @Test(".all は全件返す")
    func applyAll() {
        let entry = MangaEntry(name: "x")
        let items: [TimelineItem] = [.memo(entry)]
        #expect(TimelineFilter.all.apply(to: items).count == 1)
    }

    @Test(".memo はメモだけ返す")
    func applyMemoOnly() {
        let entry = MangaEntry(name: "x")
        let activity = ReadingActivity(date: Date(), mangaName: "x", mangaEntryID: entry.id)
        let items: [TimelineItem] = [.memo(entry), .read(activity, entry)]
        let filtered = TimelineFilter.memo.apply(to: items)
        #expect(filtered.count == 1)
        if case .memo = filtered[0] {} else { Issue.record("expected memo") }
    }
}

@Suite("TimelineChartGranularity")
struct TimelineChartGranularityTests {

    @Test("週は 7 日返す")
    func weekReturnsSevenDays() {
        let days = TimelineChartGranularity.week.days(containing: Date())
        #expect(days.count == 7)
    }

    @Test("月はその月の日数を返す (28-31)")
    func monthReturnsMonthDays() {
        let days = TimelineChartGranularity.month.days(containing: Date())
        #expect((28...31).contains(days.count))
    }
}
