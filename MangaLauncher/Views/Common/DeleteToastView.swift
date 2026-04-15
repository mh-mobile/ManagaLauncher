import SwiftUI

struct DeleteToastView: View {
    let count: Int
    let onUndo: () -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        HStack {
            Text("\(count)件削除しました")
                .font(theme.subheadlineFont)
                .foregroundStyle(theme.onSurface)
            Spacer()
            Button {
                onUndo()
            } label: {
                Text("元に戻す")
                    .font(theme.subheadlineFont.bold())
                    .foregroundStyle(theme.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                .fill(theme.surfaceContainerHighest)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
