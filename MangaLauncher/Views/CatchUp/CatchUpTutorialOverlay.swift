import SwiftUI

struct CatchUpTutorialOverlay: View {
    @Binding var hasSeenTutorial: Bool
    @Binding var showTutorial: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("使い方")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(InkTheme.onSurface)

                VStack(alignment: .leading, spacing: 16) {
                    tutorialRow(
                        icon: "hand.tap.fill",
                        color: InkTheme.secondary,
                        title: "タップで開く",
                        description: "カード画像をタップするとサイトを開けます"
                    )
                    tutorialRow(
                        icon: "arrow.right",
                        color: InkTheme.secondary,
                        title: "右スワイプ → 既読",
                        description: "読み終わったマンガを既読にします"
                    )
                    tutorialRow(
                        icon: "arrow.left",
                        color: InkTheme.tertiary,
                        title: "左スワイプ → あとで",
                        description: "あとで読むマンガをスキップします"
                    )
                    tutorialRow(
                        icon: "arrow.uturn.backward",
                        color: InkTheme.onSurfaceVariant,
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
                        .font(.system(size: 17, weight: .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(InkTheme.primary)
                        .foregroundStyle(InkTheme.onPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                    .fill(InkTheme.surfaceContainerHigh)
            )
            .overlay {
                RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                    .inset(by: 0.5)
                    .stroke(InkTheme.surfaceContainerHighest, lineWidth: 1)
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    private func tutorialRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(InkTheme.onSurface)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(InkTheme.onSurfaceVariant)
            }
        }
    }
}
