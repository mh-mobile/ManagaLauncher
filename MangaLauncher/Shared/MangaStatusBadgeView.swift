import SwiftUI

/// マンガの状態（読了 / 完結 / 休載 / 積読 / 読み切り）を 1 個のバッジで表示する。
/// 優先度: 読了 > 掲載完結 > 休載 > 積読 > 読み切り
/// 該当する状態が無ければ何も描画しない。
struct MangaStatusBadgeView: View {
    enum Style {
        /// "読" "完" "休" "積" "切" などの 1 文字
        case short
        /// "読了" "完結" "休載" "積読" "読み切り" などの全名
        case full
    }

    let entry: MangaEntry
    var style: Style = .full
    var fontSize: CGFloat = 9

    var body: some View {
        if let badge = badge(for: entry) {
            Text(badge.text)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(badge.color)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private func badge(for entry: MangaEntry) -> (text: String, color: Color)? {
        if entry.readingState == .archived {
            return (style == .short ? "読" : "読了", .green)
        }
        if entry.publicationStatus == .finished {
            return (style == .short ? "完" : "完結", .blue)
        }
        if entry.publicationStatus == .hiatus {
            return (style == .short ? "休" : "休載", .orange)
        }
        if entry.readingState == .backlog {
            return (style == .short ? "積" : "積読", ThemeManager.shared.style.primary)
        }
        if entry.isOneShot {
            return (style == .short ? "切" : "読み切り", .purple)
        }
        return nil
    }
}
