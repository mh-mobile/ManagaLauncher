import Foundation
import LinkPresentation
#if canImport(UIKit)
import UIKit
#endif

enum PublisherIconError: Error, LocalizedError {
    case invalidURL
    case noImage
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:     "URL の形式が不正です"
        case .noImage:        "URL からアイコンを取得できませんでした"
        case .decodingFailed: "取得した画像を変換できませんでした"
        }
    }
}

/// 掲載誌アイコンの取得・整形ユーティリティ。
/// state を持たないので enum + static method。
/// - 第一選択: LinkPresentation (LPMetadataProvider) でメタデータ取得
/// - 失敗時フォールバック: `/favicon.ico` の直 fetch
/// - 最終的に 256x256 / 1:1 / JPEG (q=0.85) に整形して返す
///
/// ネットワーク I/O は MainActor の外で実行する想定 (await が suspension で
/// 自動的に actor を解放する)。
enum PublisherIconService {

    /// 取得結果。`data` は整形済み JPEG。
    struct FetchResult {
        let data: Data
        let sourceURL: String
    }

    /// 第一選択: LinkPresentation。失敗時は /favicon.ico フォールバック。
    static func fetchIcon(for urlString: String) async throws -> FetchResult {
        guard let url = normalizedURL(from: urlString) else {
            throw PublisherIconError.invalidURL
        }

        if let data = try? await fetchViaLinkPresentation(url: url) {
            return FetchResult(data: data, sourceURL: url.absoluteString)
        }
        if let data = try await fetchFaviconFallback(origin: url) {
            return FetchResult(data: data, sourceURL: url.absoluteString)
        }
        throw PublisherIconError.noImage
    }

    /// PhotosPicker から取得した raw 画像データを保存用に整形する。
    /// 設定シートのプレビュー用にも使う。
    static func prepareLocalIcon(from rawData: Data) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(data: rawData) else { return nil }
        return cropAndResize(image)
        #else
        return nil
        #endif
    }

    // MARK: - LinkPresentation

    private static func fetchViaLinkPresentation(url: URL) async throws -> Data? {
        let provider = LPMetadataProvider()
        provider.timeout = 6
        let metadata = try await provider.startFetchingMetadata(for: url)
        guard let imageProvider = metadata.iconProvider ?? metadata.imageProvider else {
            return nil
        }
        let object = try await loadImage(from: imageProvider)
        #if canImport(UIKit)
        guard let uiImage = object as? UIImage else { return nil }
        return cropAndResize(uiImage)
        #else
        return nil
        #endif
    }

    /// `loadObject(ofClass:)` のコールバック版を async 化するブリッジ。
    private static func loadImage(from provider: NSItemProvider) async throws -> NSItemProviderReading? {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<NSItemProviderReading?, Error>) in
            #if canImport(UIKit)
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: object)
            }
            #else
            cont.resume(returning: nil)
            #endif
        }
    }

    // MARK: - /favicon.ico fallback

    private static func fetchFaviconFallback(origin: URL) async throws -> Data? {
        guard let scheme = origin.scheme, let host = origin.host,
              var components = URLComponents(string: "\(scheme)://\(host)") else { return nil }
        components.path = "/favicon.ico"
        guard let icoURL = components.url else { return nil }

        let (data, response) = try await URLSession.shared.data(from: icoURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return cropAndResize(uiImage)
        #else
        return nil
        #endif
    }

    // MARK: - Image transform

    /// 中央正方形クロップ → target x target へリサイズ → JPEG q=0.85。
    /// 表示は最大 96pt 程度なので 256 で 2.7x、十分な解像度。
    /// internal 公開: 設定シートの PhotosPicker / プレビューでも同じ整形ロジックを使う。
    #if canImport(UIKit)
    static func cropAndResize(_ image: UIImage, target: CGFloat = 256) -> Data? {
        let size = image.size
        let edge = min(size.width, size.height)
        guard edge > 0, let cg = image.cgImage else { return nil }
        let scale = image.scale
        let cropRect = CGRect(
            x: (size.width  - edge) / 2 * scale,
            y: (size.height - edge) / 2 * scale,
            width:  edge * scale,
            height: edge * scale
        )
        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        let croppedUI = UIImage(cgImage: cropped, scale: scale, orientation: image.imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target))
        let resized = renderer.image { _ in
            croppedUI.draw(in: CGRect(x: 0, y: 0, width: target, height: target))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
    #endif

    // MARK: - URL normalization

    private static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("http") {
            return URL(string: trimmed)
        }
        return URL(string: "https://\(trimmed)")
    }
}
