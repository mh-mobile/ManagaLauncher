import Foundation
import FoundationModels

@Generable
struct ExtractedMangaInfo {
    @Guide(description: "メインの固有名詞。サービス名とは異なるもの。")
    var title: String

    @Guide(description: "URL")
    var url: String

    @Guide(description: "サービス名やプラットフォーム名")
    var publisher: String
}

enum MangaExtractor {
    struct ExtractionResult {
        var title: String
        var url: String
        var publisher: String
        var method: String
    }

    static func extract(sharedText: String, sharedURL: String) async -> ExtractionResult {
        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            return ExtractionResult(title: "", url: sharedURL, publisher: "", method: "unavailable")
        }

        do {
            let session = LanguageModelSession()
            let prompt = """
            以下のテキストから2つの異なる固有名詞を抽出してください。

            \(sharedText)
            """
            let response = try await session.respond(to: prompt, generating: ExtractedMangaInfo.self)
            let info = response.content
            return ExtractionResult(title: info.title, url: info.url, publisher: info.publisher, method: "ai")
        } catch {
            return ExtractionResult(title: "", url: sharedURL, publisher: "", method: "error: \(error)")
        }
    }
}
