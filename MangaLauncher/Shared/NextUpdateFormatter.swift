import Foundation

/// `MangaEntry.nextExpectedUpdate` を View 表示用の文字列に整形するヘルパー。
/// 近日 (今日 / 明日 / N 日後) は相対表現、それ以遠は絶対日付、
/// 過去日は「期日超過」とそれぞれ用途別の labeling を返す。
enum NextUpdateFormatter {

    enum Style: Equatable {
        /// 通常: 直近のみ表示する。グリッドのバッジ用途。
        ///   - 今日 / 明日 / N 日後 のみ。それ以遠 (>= 8 日 or 過去) は nil
        case compact

        /// 詳細: 常に何かを返す。リストの行末用途。
        ///   - 今日 / 明日 / N 日後 / 絶対日付 / 期日超過
        case full
    }

    enum Result: Equatable {
        case upcoming(text: String, isImminent: Bool) // isImminent: 今日 or 明日
        case overdue(text: String) // nextExpectedUpdate < 今日

        /// VoiceOver の追加読み上げに使う文字列。
        var accessibilityText: String {
            switch self {
            case .upcoming(let text, _): return "次回更新 \(text)"
            case .overdue(let text): return text
            }
        }
    }

    /// 表示テキストと「強調すべきか」のフラグを返す。nil の場合は表示しない。
    static func format(_ date: Date?, style: Style, now: Date = Date()) -> Result? {
        guard let date else { return nil }
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        if days < 0 {
            switch style {
            case .compact:
                return nil // グリッドでは過去は出さない
            case .full:
                return .overdue(text: "期日超過")
            }
        }

        if days == 0 { return .upcoming(text: "今日", isImminent: true) }
        if days == 1 { return .upcoming(text: "明日", isImminent: true) }
        if days <= 7 { return .upcoming(text: "あと\(days)日", isImminent: false) }

        switch style {
        case .compact:
            return nil // 1 週間より先はグリッドでは出さない
        case .full:
            return .upcoming(text: Self.absoluteFormatter.string(from: date), isImminent: false)
        }
    }

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return f
    }()
}
