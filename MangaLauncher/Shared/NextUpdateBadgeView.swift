import SwiftUI

/// `NextUpdateFormatter.Result` を表示するスタイル付きラベル。
/// MangaRowCell / MangaGridCell の両方から使う。
struct NextUpdateBadgeView: View {
    let result: NextUpdateFormatter.Result

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        switch result {
        case .upcoming(let text, let isImminent):
            Text(text)
                .font(.caption2.weight(isImminent ? .bold : .regular))
                .foregroundStyle(isImminent ? theme.primary : theme.onSurfaceVariant)
        case .overdue(let text):
            Text(text)
                .font(.caption2.weight(.semibold))
                // 期日超過は注意喚起。ハードコードの .orange ではなくテーマに沿った
                // error 色を使うことで Classic / Ink / Retro 各テーマに馴染ませる。
                .foregroundStyle(theme.error)
        }
    }
}
