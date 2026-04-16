//
//  NextUpdateFormatterTests.swift
//  MangaLauncherTests
//
//  日付→表示文字列変換の境界値テスト。
//  now パラメータで決定論的に検証。
//

import Testing
import Foundation
@testable import MangaLauncher

@Suite("NextUpdateFormatter")
struct NextUpdateFormatterTests {

    private let now = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_900_000_000))

    private func days(_ delta: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: delta, to: now)!
    }

    // MARK: - 共通ロジック

    @Test("nil は常に nil を返す")
    func nilReturnsNil() {
        #expect(NextUpdateFormatter.format(nil, style: .compact, now: now) == nil)
        #expect(NextUpdateFormatter.format(nil, style: .full, now: now) == nil)
    }

    @Test("0 日 (今日) は imminent 「今日」")
    func today() {
        let r = NextUpdateFormatter.format(now, style: .full, now: now)
        #expect(r == .upcoming(text: "今日", isImminent: true))
    }

    @Test("1 日 (明日) は imminent 「明日」")
    func tomorrow() {
        let r = NextUpdateFormatter.format(days(1), style: .full, now: now)
        #expect(r == .upcoming(text: "明日", isImminent: true))
    }

    @Test("2-7 日は通常 「あと N 日」")
    func upcomingDays() {
        let r3 = NextUpdateFormatter.format(days(3), style: .full, now: now)
        #expect(r3 == .upcoming(text: "あと3日", isImminent: false))

        let r7 = NextUpdateFormatter.format(days(7), style: .full, now: now)
        #expect(r7 == .upcoming(text: "あと7日", isImminent: false))
    }

    // MARK: - スタイル別

    @Test("compact: 8 日以上先は nil")
    func compactHidesFar() {
        #expect(NextUpdateFormatter.format(days(8), style: .compact, now: now) == nil)
        #expect(NextUpdateFormatter.format(days(30), style: .compact, now: now) == nil)
    }

    @Test("full: 8 日以上先は絶対日付を返す")
    func fullShowsAbsolute() {
        let r = NextUpdateFormatter.format(days(8), style: .full, now: now)
        if case .upcoming(let text, let isImminent) = r {
            #expect(!text.isEmpty)
            #expect(isImminent == false)
        } else {
            Issue.record("expected .upcoming with absolute text")
        }
    }

    @Test("compact: 過去日は nil")
    func compactHidesOverdue() {
        #expect(NextUpdateFormatter.format(days(-1), style: .compact, now: now) == nil)
        #expect(NextUpdateFormatter.format(days(-100), style: .compact, now: now) == nil)
    }

    @Test("full: 過去日は overdue 「期日超過」")
    func fullShowsOverdue() {
        let r = NextUpdateFormatter.format(days(-1), style: .full, now: now)
        #expect(r == .overdue(text: "期日超過"))
    }

    // MARK: - accessibilityText

    @Test("accessibilityText が VoiceOver 用文字列を返す")
    func accessibilityText() {
        #expect(NextUpdateFormatter.Result.upcoming(text: "今日", isImminent: true).accessibilityText == "次回更新 今日")
        #expect(NextUpdateFormatter.Result.upcoming(text: "あと3日", isImminent: false).accessibilityText == "次回更新 あと3日")
        #expect(NextUpdateFormatter.Result.overdue(text: "期日超過").accessibilityText == "期日超過")
    }
}
