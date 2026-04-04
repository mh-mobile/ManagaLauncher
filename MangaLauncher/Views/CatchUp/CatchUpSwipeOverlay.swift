import SwiftUI

struct CatchUpSwipeOverlay: View {
    let offsetWidth: CGFloat

    var body: some View {
        if offsetWidth > 30 {
            RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                .fill(InkTheme.secondary.opacity(0.15))
                .overlay {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60, weight: .black))
                            .foregroundStyle(InkTheme.secondary)
                        Text("既読")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(InkTheme.secondary)
                    }
                }
                .opacity(min(Double(offsetWidth) / 100, 1))
        } else if offsetWidth < -30 {
            RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                .fill(InkTheme.tertiary.opacity(0.15))
                .overlay {
                    VStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60, weight: .black))
                            .foregroundStyle(InkTheme.tertiary)
                        Text("あとで")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(InkTheme.tertiary)
                    }
                }
                .opacity(min(Double(-offsetWidth) / 100, 1))
        }
    }
}
