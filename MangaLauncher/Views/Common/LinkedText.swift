import SwiftUI

/// テキスト中の URL を自動検出してタップ可能なリンクとして表示する View。
/// SwiftUI の Text + AttributedString を利用し、リンク部分はテーマカラーで着色される。
struct LinkedText: View {
    let text: String
    let font: Font
    let foregroundColor: Color
    let linkColor: Color
    let onOpenURL: ((URL) -> OpenURLAction.Result)?

    /// URL 検出用の NSDataDetector。生成コストを避けるためインスタンスを共有する。
    private static let linkDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    init(
        _ text: String,
        font: Font = .body,
        foregroundColor: Color = .primary,
        linkColor: Color? = nil,
        onOpenURL: ((URL) -> OpenURLAction.Result)? = nil
    ) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.linkColor = linkColor ?? ThemeManager.shared.style.primary
        self.onOpenURL = onOpenURL
    }

    var body: some View {
        Text(Self.buildAttributedString(from: text, foregroundColor: foregroundColor, linkColor: linkColor))
            .font(font)
            .tint(linkColor)
            .environment(\.openURL, OpenURLAction { url in
                if let onOpenURL {
                    return onOpenURL(url)
                }
                return .systemAction(url)
            })
    }

    // MARK: - AttributedString 構築（テスト可能な static メソッド）

    /// テキスト中の URL を検出してリンク属性を付与した AttributedString を返す。
    static func buildAttributedString(
        from text: String,
        foregroundColor: Color,
        linkColor: Color
    ) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = foregroundColor

        // URL を含まないテキストは早期リターン
        guard let detector = linkDetector else { return result }
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = detector.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return result }

        for match in matches {
            guard let url = match.url,
                  let swiftRange = Range(match.range, in: text) else { continue }
            // String.Index のオフセットを使って AttributedString の範囲を算出
            let startOffset = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: swiftRange.upperBound)
            let attrStart = result.index(result.startIndex, offsetByCharacters: startOffset)
            let attrEnd = result.index(result.startIndex, offsetByCharacters: endOffset)
            let attrRange = attrStart..<attrEnd
            result[attrRange].link = url
            result[attrRange].foregroundColor = linkColor
            result[attrRange].underlineStyle = .single
        }

        return result
    }
}
