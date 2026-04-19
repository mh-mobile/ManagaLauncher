import Foundation

extension MangaEntry {
    var episodeDisplayText: String? {
        if let label = episodeLabel, !label.isEmpty { return "既読 \(label)" }
        if let ep = currentEpisode { return "既読 \(ep)話" }
        return nil
    }

    func accessibilityDescription(nextUpdateStyle: NextUpdateFormatter.Style, showsNextUpdateBadge: Bool) -> String {
        var parts = [name]
        if !publisher.isEmpty { parts.append(publisher) }
        if let text = episodeDisplayText { parts.append(text) }
        if !isRead { parts.append("未読") }
        if showsNextUpdateBadge,
           let next = NextUpdateFormatter.format(nextExpectedUpdate, style: nextUpdateStyle) {
            parts.append(next.accessibilityText)
        }
        return parts.joined(separator: "、")
    }
}
