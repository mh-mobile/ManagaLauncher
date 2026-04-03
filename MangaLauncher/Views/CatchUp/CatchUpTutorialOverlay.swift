import SwiftUI

struct CatchUpTutorialOverlay: View {
    @Binding var hasSeenTutorial: Bool
    @Binding var showTutorial: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("使い方")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 16) {
                    tutorialRow(
                        icon: "hand.tap.fill",
                        color: .blue,
                        title: "タップで開く",
                        description: "カード画像をタップするとサイトを開けます"
                    )
                    tutorialRow(
                        icon: "arrow.right",
                        color: .green,
                        title: "右スワイプ → 既読",
                        description: "読み終わったマンガを既読にします"
                    )
                    tutorialRow(
                        icon: "arrow.left",
                        color: .orange,
                        title: "左スワイプ → あとで",
                        description: "あとで読むマンガをスキップします"
                    )
                    tutorialRow(
                        icon: "arrow.uturn.backward",
                        color: .secondary,
                        title: "元に戻す",
                        description: "ツールバーのボタンで直前の操作を取り消せます"
                    )
                }

                Button {
                    withAnimation {
                        hasSeenTutorial = true
                        showTutorial = false
                    }
                } label: {
                    Text("OK")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .frame(maxWidth: 400)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    private func tutorialRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
