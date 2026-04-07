import SwiftUI

struct CatchUpSwipeOverlay: View {
    let offsetWidth: CGFloat

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        if offsetWidth > 30 {
            RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                .fill(theme.catchUpReadColor.opacity(0.15))
                .overlay {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(theme.forceDarkMode ? .system(size: 60, weight: .black) : .system(size: 60))
                            .foregroundStyle(theme.catchUpReadColor)
                        Text("既読")
                            .font(theme.title2Font)
                            .foregroundStyle(theme.catchUpReadColor)
                    }
                }
                .opacity(min(Double(offsetWidth) / 100, 1))
        } else if offsetWidth < -30 {
            RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                .fill(theme.catchUpSkipColor.opacity(0.15))
                .overlay {
                    VStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(theme.forceDarkMode ? .system(size: 60, weight: .black) : .system(size: 60))
                            .foregroundStyle(theme.catchUpSkipColor)
                        Text("あとで")
                            .font(theme.title2Font)
                            .foregroundStyle(theme.catchUpSkipColor)
                    }
                }
                .opacity(min(Double(-offsetWidth) / 100, 1))
        }
    }
}
