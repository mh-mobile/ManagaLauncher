import Foundation

/// 検索クエリのマッチ箇所周辺を抜き出して短い断片を返す。
/// 長文のメモやコメントから「ヒット箇所はこの辺」を可視化するために使う。
enum SearchSnippet {
    static func make(from text: String, query: String, padding: Int = 20) -> String {
        guard !query.isEmpty,
              let range = text.range(of: query, options: .caseInsensitive) else {
            return text
        }
        let lowerOffset = text.distance(from: text.startIndex, to: range.lowerBound)
        let startOffset = max(0, lowerOffset - padding)
        let startIndex = text.index(text.startIndex, offsetBy: startOffset)
        let prefix = startOffset > 0 ? "…" : ""
        let snippet = text[startIndex...]
        return prefix + String(snippet)
    }
}
