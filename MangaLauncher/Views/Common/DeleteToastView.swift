import SwiftUI

struct DeleteToastView: View {
    var viewModel: MangaViewModel

    var body: some View {
        let count = viewModel.pendingDeleteEntries.count
        HStack {
            Text("\(count)件削除しました")
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                viewModel.undoPendingDeletes()
            } label: {
                Text("元に戻す")
                    .font(.subheadline.bold())
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.darkGray))
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
