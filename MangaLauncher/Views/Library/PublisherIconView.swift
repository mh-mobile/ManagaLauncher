import SwiftUI
import PlatformKit

/// 掲載誌アイコンの共通表示コンポーネント。
/// - 設定済み (`iconData != nil`): 画像を正方形で表示
/// - 未設定 + `showsFallback == true`: 薄いグレーの "magazine" SF Symbol
/// - 未設定 + `showsFallback == false`: EmptyView (テキスト前置き用、未設定時はスペースも消える)
///
/// `showsFallback` の使い分け:
/// - AllPublishersView 等の「掲載誌の専用画面」では true (空白を埋めて視覚的に寂しさを軽減)
/// - エントリ表示やフィルタ chip 等の「掲載誌が脇役の場所」では false (アイコンは意味を持つ要素として扱う)
struct PublisherIconView: View {
    let iconData: Data?
    let size: CGFloat
    var showsFallback: Bool = false

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        if let iconData, let image = iconData.toSwiftUIImage() {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(2, size * 0.18)))
        } else if showsFallback {
            Image(systemName: "magazine")
                .font(.system(size: size * 0.7))
                .foregroundStyle(theme.onSurfaceVariant.opacity(0.35))
                .frame(width: size, height: size)
        } else {
            EmptyView()
        }
    }
}
