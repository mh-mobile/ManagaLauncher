import SwiftUI
import PlatformKit

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(theme.captionFont)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? theme.primary : theme.surfaceContainerHigh)
                .foregroundStyle(isSelected ? theme.onPrimary : theme.onSurfaceVariant)
                .clipShape(theme.chipShape)
        }
        .buttonStyle(.plain)
    }
}
