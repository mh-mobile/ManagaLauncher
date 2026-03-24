import Foundation
import FoundationModels

enum MangaExtractor {
    struct ExtractionResult {
        var title: String
        var url: String
        var publisher: String
        var method: String
    }

    static func extract(sharedText: String, sharedURL: String) async -> ExtractionResult {
        let model = SystemLanguageModel.default

        guard model.isAvailable, !sharedText.isEmpty else {
            return ExtractionResult(title: "", url: sharedURL, publisher: "", method: "unavailable")
        }

        let cleanedText = cleanSharedText(sharedText)

        let title = await extractTitle(from: cleanedText)
        let publisher = await extractPublisher(from: cleanedText)

        let method = (title != nil || publisher != nil) ? "ai" : "error"
        return ExtractionResult(
            title: title ?? "",
            url: sharedURL,
            publisher: publisher ?? "",
            method: method
        )
    }

    private static func extractTitle(from text: String) async -> String? {
        do {
            let session = LanguageModelSession()
            let prompt = """
            次のテキストから作品タイトルのみを1つ抽出してください。
            話数や記号は除外してください。
            出力はタイトルのみ。

            テキスト:
            \(text)
            """
            let response = try await session.respond(to: prompt)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return isValidExtraction(result) ? result : nil
        } catch {
            return nil
        }
    }

    private static func extractPublisher(from text: String) async -> String? {
        do {
            let session = LanguageModelSession()
            let prompt = """
            次のテキストから掲載誌のみを1つ抽出してください。
            話数や記号は除外してください。
            出力は掲載誌のみ。

            テキスト:
            \(text)
            """
            let response = try await session.respond(to: prompt)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return isValidExtraction(result) ? result : nil
        } catch {
            return nil
        }
    }

    private static func cleanSharedText(_ text: String) -> String {
        var cleaned = text
        let signatures = [
            "iPhoneから送信",
            "iPadから送信",
            "Macから送信",
            "Sent from my iPhone",
            "Sent from my iPad",
            "Sent from my Mac",
        ]
        for signature in signatures {
            cleaned = cleaned.replacingOccurrences(of: signature, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValidExtraction(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        if text == "なし" { return false }
        if text.count > 50 { return false }
        return true
    }
}
