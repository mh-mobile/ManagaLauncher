import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: (() -> Void)?
    @State private var currentPage = 0

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var pages: [(icon: String, title: String, description: String, color: Color)] {
        let colors = theme.onboardingColors
        return [
            ("calendar", "曜日ごとに管理", "週間連載のマンガを曜日ごとに登録。\n今日読むマンガがひと目で分かります。", colors[0]),
            ("rectangle.stack", "キャッチアップ", "カードスワイプで未読マンガをチェック。\n右スワイプで既読、左スワイプであとで。", colors[1]),
            ("square.grid.2x2", "ウィジェット & 通知", "ホーム画面のウィジェットから\n今日のマンガをすぐに確認。\n指定時間にリマインド通知も。", colors[2]),
            ("square.and.arrow.up", "かんたん登録", "マンガアプリやブラウザの共有ボタンから\nワンタップで登録できます。", colors[3]),
        ]
    }

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    pageView(page: pages[index])
                        .tag(index)
                }
            }
            #if os(iOS) || os(visionOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    if let onComplete {
                        onComplete()
                    } else {
                        dismiss()
                    }
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "次へ" : "はじめる")
                    .font(theme.headlineFont)
                    .frame(maxWidth: 320)
                    .padding()
                    .background(theme.primary)
                    .foregroundStyle(theme.onPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            Button("スキップ") {
                if let onComplete {
                    onComplete()
                } else {
                    dismiss()
                }
            }
            .font(theme.subheadlineFont)
            .foregroundStyle(theme.onSurfaceVariant)
            .padding(.bottom, 8)
            .opacity(currentPage < pages.count - 1 ? 1 : 0)
        }
        .if(theme.forceDarkMode) { view in
            view.background(theme.surface)
        }
    }

    private func pageView(page: (icon: String, title: String, description: String, color: Color)) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 72))
                .fontWeight(theme.forceDarkMode ? .bold : .regular)
                .foregroundStyle(page.color)

            Text(page.title)
                .font(.title.weight(theme.forceDarkMode ? .black : .bold))
                .foregroundStyle(theme.onSurface)

            Text(page.description)
                .font(theme.bodyFont)
                .foregroundStyle(theme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}
