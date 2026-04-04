import SwiftUI
import PlatformKit

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? InkTheme.secondary : InkTheme.surfaceContainerHigh)
                .foregroundStyle(isSelected ? InkTheme.onPrimary : InkTheme.onSurfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: InkTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}
