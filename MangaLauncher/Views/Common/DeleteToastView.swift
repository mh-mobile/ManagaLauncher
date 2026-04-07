import SwiftUI

struct DeleteToastView: View {
    var viewModel: MangaViewModel

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        let count = viewModel.pendingDeleteEntries.count
        HStack {
            Text("\(count)件削除しました")
                .font(theme.subheadlineFont)
                .foregroundStyle(theme.onSurface)
            Spacer()
            Button {
                viewModel.undoPendingDeletes()
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
