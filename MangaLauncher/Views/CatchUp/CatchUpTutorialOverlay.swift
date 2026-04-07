import SwiftUI

struct CatchUpTutorialOverlay: View {
    @Binding var hasSeenTutorial: Bool
    @Binding var showTutorial: Bool

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        ZStack {
            Color.black.opacity(theme.forceDarkMode ? 0.7 : 0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("使い方")
                    .font(theme.title2Font)
                    .foregroundStyle(theme.forceDarkMode ? theme.onSurface : .white)

                VStack(alignment: .leading, spacing: 16) {
                    tutorialRow(
                        icon: "hand.tap.fill",
                        color: theme.tutorialColors.tap,
                        title: "タップで開く",
                        description: "カード画像をタップするとサイトを開けます"
                    )
                    tutorialRow(
                        icon: "arrow.right",
                        color: theme.tutorialColors.read,
                        title: "右スワイプ → 既読",
                        description: "読み終わったマンガを既読にします"
                    )
                    tutorialRow(
                        icon: "arrow.left",
                        color: theme.tutorialColors.skip,
                        title: "左スワイプ → あとで",
                        description: "あとで読むマンガをスキップします"
                    )
                    tutorialRow(
                        icon: "arrow.uturn.backward",
                        color: theme.tutorialColors.undo,
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
                        .font(theme.headlineFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primary)
                        .foregroundStyle(theme.onPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
                }
            }
            .padding(24)
            .background(
                Group {
                    switch ThemeManager.shared.mode {
                    case .ink:
                        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                            .fill(theme.surfaceContainerHigh)
                    case .classic:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .if(theme.forceDarkMode) { view in
                view.overlay {
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                        .inset(by: 0.5)
                        .stroke(theme.surfaceContainerHighest, lineWidth: 1)
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    private func tutorialRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(theme.title3Font)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.subheadlineFont)
                    .foregroundStyle(theme.forceDarkMode ? theme.onSurface : .white)
                Text(description)
                    .font(theme.captionFont)
                    .foregroundStyle(theme.forceDarkMode ? theme.onSurfaceVariant : .white.opacity(0.8))
            }
        }
    }
}
