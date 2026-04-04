import SwiftUI

struct EmptyStateView<Content: View>: View {
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    let headerHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if hasWallpaper {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, headerHeight)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                            .fill(InkTheme.surfaceContainerHigh)
                        RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                            .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                    }
                    .padding()
                    .padding(.top, headerHeight)
                }
        } else {
            content()
                .padding(.top, headerHeight)
                .background(InkTheme.surface)
        }
    }
}
