import Foundation

extension MangaEntry {
    func accessibilityDescription(nextUpdateStyle: NextUpdateFormatter.Style, showsNextUpdateBadge: Bool) -> String {
        var parts = [name]
        if !publisher.isEmpty { parts.append(publisher) }
        if !isRead { parts.append("未読") }
        if showsNextUpdateBadge,
           let next = NextUpdateFormatter.format(nextExpectedUpdate, style: nextUpdateStyle) {
            parts.append(next.accessibilityText)
        }
        return parts.joined(separator: "、")
    }
}
