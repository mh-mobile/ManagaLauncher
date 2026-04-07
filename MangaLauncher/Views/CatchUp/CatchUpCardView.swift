import SwiftUI
import PlatformKit

struct CatchUpCardView: View {
    let entry: MangaEntry
    @Binding var editingEntry: MangaEntry?
    let onOpenURL: (String) -> Void
    var hasGradientBackground: Bool = false

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        cardContent
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

    // MARK: - Card Cover

    @ViewBuilder
    private var cardCover: some View {
        if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
            image
                .resizable()
                .scaledToFit()
        } else {
            Color.fromName(entry.iconColor)
                .overlay {
                    Text(entry.name)
                        .font(theme.forceDarkMode ? .system(size: 28, weight: .black) : .title.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .aspectRatio(4/3, contentMode: .fit)
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        switch ThemeManager.shared.mode {
        case .ink:
            VStack(spacing: 0) {
                cardCover

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
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM + 4)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))

        case .classic:
            VStack(spacing: 12) {
                cardCover
                    .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))

                Text(entry.name)
                    .font(theme.title3Font)
                    .foregroundStyle(hasGradientBackground ? .white : theme.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if !entry.publisher.isEmpty {
                    Text(entry.publisher)
                        .font(theme.subheadlineFont)
                        .foregroundStyle(hasGradientBackground ? .white.opacity(0.7) : theme.onSurfaceVariant)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(theme.hasShadows ? 0.1 : 0), radius: 8, y: 4)
            )

        case .retro:
            VStack(spacing: 0) {
                cardCover

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
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM + 4)
                .frame(maxWidth: .infinity)
                .background(theme.surfaceContainerHigh)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 6, bottomTrailingRadius: 14, topTrailingRadius: 6))
        }
    }
}
