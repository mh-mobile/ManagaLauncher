import SwiftUI

/// 5段階の星評価を表示・操作するための再利用可能コンポーネント。
///
/// - Display-only: `StarRatingView(rating: entry.personalRating, size: 10)`
/// - Interactive: `StarRatingView(rating: rating, size: 22) { newRating in ... }`
struct StarRatingView: View {
    let rating: Int?
    var maxRating: Int = 5
    var size: CGFloat = 14
    /// nil の場合は表示専用（タップ不可）。
    var onRate: ((Int?) -> Void)? = nil

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        HStack(spacing: size > 16 ? 4 : 2) {
            ForEach(1...maxRating, id: \.self) { star in
                let isFilled = star <= (rating ?? 0)
                Image(systemName: isFilled ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(isFilled ? .yellow : theme.onSurfaceVariant.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let onRate else { return }
                        // 同じ星をタップで評価解除
                        onRate(star == rating ? nil : star)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ratingAccessibilityLabel)
        .accessibilityValue(ratingAccessibilityValue)
    }

    private var ratingAccessibilityLabel: String {
        "パーソナル評価"
    }

    private var ratingAccessibilityValue: String {
        if let rating {
            "\(rating)つ星"
        } else {
            "未評価"
        }
    }
}
