import SwiftUI
import PlatformKit

struct CatchUpCardView: View {
    let entry: MangaEntry
    @Binding var editingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.fromName(entry.iconColor))
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        Text(entry.name)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
            }

            Text(entry.name)
                .font(.title3.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if !entry.publisher.isEmpty {
                Text(entry.publisher)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
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
