import SwiftUI

/// セクションヘッダーの共通コンポーネント。
/// アイコン + タイトル + 件数バッジ + （任意）「すべて表示」リンク。
struct SectionHeaderView<Destination: Hashable>: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color? = nil
    var count: Int? = nil
    var badgeColor: Color? = nil
    var seeAll: Destination? = nil

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(theme.headlineFont)
                    .foregroundStyle(iconColor ?? theme.primary)
            }
            Text(title)
                .font(theme.title3Font)
                .foregroundStyle(theme.onSurface)
            if let count {
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.onPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(badgeColor ?? theme.primary)
                    .clipShape(Capsule())
            }
            Spacer()
            if let seeAll {
                NavigationLink(value: seeAll) {
                    HStack(spacing: 2) {
                        Text("すべて表示")
                            .font(theme.captionFont)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(theme.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension SectionHeaderView where Destination == LibraryDestination {
    /// 「すべて表示」リンクが不要なケース用
    init(title: String, icon: String? = nil, iconColor: Color? = nil, count: Int? = nil, badgeColor: Color? = nil) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.count = count
        self.badgeColor = badgeColor
        self.seeAll = nil
    }
}
