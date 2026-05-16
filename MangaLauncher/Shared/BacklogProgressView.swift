import SwiftUI

/// 積読マンガの読書進捗を表示する再利用可能コンポーネント。
///
/// `readingState == .backlog` かつ `currentEpisode` と `latestEpisode` の
/// 両方が設定されている場合のみ表示される。
///
/// Usage: `BacklogProgressView(entry: entry, fontSize: 9)`
struct BacklogProgressView: View {
    let entry: MangaEntry
    var fontSize: CGFloat = 10
    var barHeight: CGFloat = 3

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        if entry.showsBacklogProgress,
           let current = entry.currentEpisode,
           let latest = entry.latestEpisode {
            let fraction = latest > 0 ? min(1.0, Double(current) / Double(latest)) : 0
            VStack(alignment: .leading, spacing: 2) {
                Text("\(current) / \(latest)話")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(theme.onSurfaceVariant)

                ProgressView(value: fraction)
                    .tint(theme.primary)
                    .frame(height: barHeight)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("積読進捗 \(current)/\(latest)話")
        }
    }
}
