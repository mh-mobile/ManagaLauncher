import SwiftUI

/// テキスト中の URL を自動検出してタップ可能なリンクとして表示する View。
/// SwiftUI の Text + AttributedString を利用し、リンク部分はテーマカラーで着色される。
struct LinkedText: View {
    let text: String
    let font: Font
    let foregroundColor: Color
    let linkColor: Color

    init(
        _ text: String,
        font: Font = .body,
        foregroundColor: Color = .primary,
        linkColor: Color? = nil
    ) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.linkColor = linkColor ?? ThemeManager.shared.style.primary
    }

    var body: some View {
        Text(buildAttributedString())
            .font(font)
            .tint(linkColor)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = foregroundColor

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return result
        }

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = detector.matches(in: text, options: [], range: fullRange)

        for match in matches {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let attrRange = result.range(of: text[range]) else { continue }
            result[attrRange].link = url
            result[attrRange].foregroundColor = linkColor
            result[attrRange].underlineStyle = .single
        }

        return result
    }
}

// MARK: - AttributedString range helper

private extension AttributedString {
    /// String の Range を AttributedString 内で検索して対応する範囲を返す。
    /// 同じ部分文字列が複数回出現する場合に正しい位置を返すため、
    /// 先頭からのオフセットを利用する。
    func range(of substring: Substring) -> Range<AttributedString.Index>? {
        let text = String(self.characters)
        guard let stringRange = text.range(of: substring) else { return nil }
        let startOffset = text.distance(from: text.startIndex, to: stringRange.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: stringRange.upperBound)
        let attrStart = self.index(self.startIndex, offsetByCharacters: startOffset)
        let attrEnd = self.index(self.startIndex, offsetByCharacters: endOffset)
        return attrStart..<attrEnd
    }
}
