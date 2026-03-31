import Foundation
import FoundationModels

@Generable
public struct ExtractedMangaInfo {
    @Guide(description: "メインの固有名詞。サービス名とは異なるもの。")
    public var title: String

    @Guide(description: "URL")
    public var url: String

    @Guide(description: "サービス名やプラットフォーム名")
    public var publisher: String
}

public enum MangaExtractor {
    public struct ExtractionResult {
        public var title: String
        public var url: String
        public var publisher: String
        public var method: String

        public init(title: String, url: String, publisher: String, method: String) {
            self.title = title
            self.url = url
            self.publisher = publisher
            self.method = method
        }
    }

    public static func extract(sharedText: String, sharedURL: String) async -> ExtractionResult {
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
