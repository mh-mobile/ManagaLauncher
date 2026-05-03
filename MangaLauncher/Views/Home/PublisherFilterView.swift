import SwiftUI
import PlatformKit

struct PublisherFilterView: View {
    let publishers: [String]
    var viewModel: MangaViewModel
    @Binding var selectedPublisher: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "すべて", isSelected: selectedPublisher == nil) {
                    withAnimation { selectedPublisher = nil }
                }
                ForEach(publishers, id: \.self) { pub in
                    PublisherFilterChip(
                        publisher: pub,
                        iconData: viewModel.publisherIcon(for: pub),
                        isSelected: selectedPublisher == pub
                    ) {
                        withAnimation { selectedPublisher = selectedPublisher == pub ? nil : pub }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

/// アイコン付きの publisher 専用 chip。アイコン未設定なら text のみ。
private struct PublisherFilterChip: View {
    let publisher: String
    let iconData: Data?
    let isSelected: Bool
    let action: () -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if iconData != nil {
                    PublisherIconView(iconData: iconData, size: 14)
                }
                Text(publisher)
                    .font(theme.captionFont)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? theme.primary : theme.surfaceContainerHigh)
            .foregroundStyle(isSelected ? theme.onPrimary : theme.onSurfaceVariant)
            .clipShape(theme.chipShape)
        }
        .buttonStyle(.plain)
    }
}
