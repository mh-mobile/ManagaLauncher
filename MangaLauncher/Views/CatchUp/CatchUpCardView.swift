import SwiftUI
import PlatformKit

struct CatchUpCardView: View {
    let entry: MangaEntry
    @Binding var editingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        switch ThemeManager.shared.mode {
        case .ink:
            inkCard
        case .classic:
            classicCard
        }
    }

    // MARK: - Ink Card

    private var inkCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                        .fill(Color.fromName(entry.iconColor))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay {
                            ZStack {
                                if theme.usesScreenTone {
                                    ScreenTonePattern(opacity: 0.08, spacing: 4)
                                }
                                Text(entry.name)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                        }
                }
            }

            VStack(spacing: 4) {
                Text(entry.name)
                    .font(theme.title3Font)
                    .foregroundStyle(theme.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if !entry.publisher.isEmpty {
                    Text(entry.publisher)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.onSurfaceVariant)
                }
            }
            .padding(.horizontal, InkTheme.spacingMD)
            .padding(.vertical, InkTheme.spacingSM + 4)
            .frame(maxWidth: .infinity)
            .background(theme.surfaceContainerHighest)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
        .background(
            RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                .fill(theme.surfaceContainerHigh)
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

    // MARK: - Classic Card

    private var classicCard: some View {
        VStack(spacing: 12) {
            if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            } else {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
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
                .font(theme.title3Font)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if !entry.publisher.isEmpty {
                Text(entry.publisher)
                    .font(theme.subheadlineFont)
                    .foregroundStyle(theme.onSurfaceVariant)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(theme.hasShadows ? 0.1 : 0), radius: 8, y: 4)
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
