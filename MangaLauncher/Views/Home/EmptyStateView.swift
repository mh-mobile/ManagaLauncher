import SwiftUI

struct EmptyStateView<Content: View>: View {
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    let headerHeight: CGFloat
    @ViewBuilder let content: () -> Content

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        if hasWallpaper {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, headerHeight)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                            .fill(theme.surfaceContainerHigh)
                        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                            .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                    }
                    .padding()
                    .padding(.top, headerHeight)
                }
        } else {
            switch ThemeManager.shared.mode {
            case .classic:
                content()
                    .padding(.top, headerHeight)
            case .ink:
                content()
                    .padding(.top, headerHeight)
                    .background(theme.surface)
            }
        }
    }
}
