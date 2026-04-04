import SwiftUI

struct DeleteToastView: View {
    var viewModel: MangaViewModel

    var body: some View {
        let count = viewModel.pendingDeleteEntries.count
        HStack {
            Text("\(count)件削除しました")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(InkTheme.onSurface)
            Spacer()
            Button {
                viewModel.undoPendingDeletes()
            } label: {
                Text("元に戻す")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(InkTheme.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                .fill(InkTheme.surfaceContainerHighest)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
