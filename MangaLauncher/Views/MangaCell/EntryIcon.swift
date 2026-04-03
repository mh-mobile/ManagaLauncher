import SwiftUI
import PlatformKit

struct EntryIcon: View {
    let entry: MangaEntry
    let size: CGFloat

    var body: some View {
        if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size > 40 ? 8 : 6))
                .accessibilityLabel("\(entry.name)のアイコン")
        } else {
            Circle()
                .fill(Color.fromName(entry.iconColor))
                .frame(width: size, height: size)
                .overlay {
                    Text(String(entry.name.prefix(1)))
                        .font(size > 40 ? .title : .headline)
                        .foregroundStyle(.white)
                }
        }
    }
}
