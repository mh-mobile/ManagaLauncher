import SwiftUI
import PlatformKit

struct EntryIcon: View {
    let entry: MangaEntry
    let size: CGFloat

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size > 40 ? theme.cardCornerRadius : theme.cornerRadius))
                .accessibilityLabel("\(entry.name)のアイコン")
        } else {
            if theme.iconFallbackIsCircle {
                Circle()
                    .fill(Color.fromName(entry.iconColor))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(String(entry.name.prefix(1)))
                            .font(size > 40 ? .title : .headline)
                            .foregroundStyle(theme.onPrimary)
                    }
            } else {
                RoundedRectangle(cornerRadius: size > 40 ? theme.cardCornerRadius : theme.cornerRadius)
                    .fill(Color.fromName(entry.iconColor))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(String(entry.name.prefix(1)))
                            .font(size > 40 ? .title.bold() : .headline.bold())
                            .foregroundStyle(theme.onSurface)
                    }
            }
        }
    }
}
