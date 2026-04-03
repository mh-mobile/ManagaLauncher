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
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemFill))
                        RoundedRectangle(cornerRadius: 16)
                            .fill(reduceTransparency ? .thickMaterial : .ultraThinMaterial)
                    }
                    .padding()
                    .padding(.top, headerHeight)
                }
        } else {
            content()
                .padding(.top, headerHeight)
        }
    }
}
