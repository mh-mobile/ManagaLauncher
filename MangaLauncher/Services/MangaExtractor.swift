import Foundation
import FoundationModels

@Generable
struct ExtractedMangaInfo {
    @Guide(description: "漫画のタイトル名。エピソード番号やサイト名は含めない。")
    var title: String

    @Guide(description: "漫画の詳細ページURL")
    var url: String

    @Guide(description: "掲載誌またはサイト名（例: 少年ジャンプ+, マガポケ, サンデーうぇぶり）")
    var publisher: String
}

enum MangaExtractor {
    static func extract(sharedText: String, sharedURL: String) async -> ExtractedMangaInfo? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }
        do {
            let session = LanguageModelSession()
            let prompt = """
            以下の共有コンテンツからマンガの情報を抽出してください。

            共有URL: \(sharedURL)
            ページタイトル/テキスト: \(sharedText)

            マンガのタイトル、URL、掲載誌を抽出してください。
            """
            let response = try await session.respond(to: prompt, generating: ExtractedMangaInfo.self)
            return response.content
        } catch {
            return nil
        }
    }

    /// Fallback extraction when Foundation Models is unavailable
    static func extractFallback(sharedText: String, sharedURL: String) -> ExtractedMangaInfo {
        // Heuristic: split page title by common separators
        let separators = [" - ", " | ", " – ", "｜", "："]
        var title = sharedText
        var publisher = ""

        for separator in separators {
            let parts = sharedText.components(separatedBy: separator)
            if parts.count >= 2 {
                title = parts[0].trimmingCharacters(in: .whitespaces)
                publisher = parts.last?.trimmingCharacters(in: .whitespaces) ?? ""
                break
            }
        }

        return ExtractedMangaInfo(title: title, url: sharedURL, publisher: publisher)
    }
}
