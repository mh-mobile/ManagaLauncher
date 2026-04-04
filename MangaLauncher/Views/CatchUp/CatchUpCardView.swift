import SwiftUI
import PlatformKit

struct CatchUpCardView: View {
    let entry: MangaEntry
    @Binding var editingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Manga panel image
            ZStack(alignment: .topLeading) {
                if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                        .fill(Color.fromName(entry.iconColor))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay {
                            ZStack {
                                ScreenTonePattern(opacity: 0.08, spacing: 4)
                                Text(entry.name)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                        }
                }
            }

            // Title area
            VStack(spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(InkTheme.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if !entry.publisher.isEmpty {
                    Text(entry.publisher)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(InkTheme.onSurfaceVariant)
                }
            }
            .padding(.horizontal, InkTheme.spacingMD)
            .padding(.vertical, InkTheme.spacingSM + 4)
            .frame(maxWidth: .infinity)
            .background(InkTheme.surfaceContainerHighest)
        }
        .clipShape(RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius))
        .background(
            RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                .fill(InkTheme.surfaceContainerHigh)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.name)\(entry.publisher.isEmpty ? "" : "、\(entry.publisher)")")
        .accessibilityHint("タップでサイトを開く、長押しで編集")
        .onTapGesture {
            onOpenURL(entry.url)
        }
        .onLongPressGesture {
            editingEntry = entry
        }
    }
}
