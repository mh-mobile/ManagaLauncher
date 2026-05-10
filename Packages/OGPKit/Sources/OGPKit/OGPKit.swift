import Foundation
import PlatformKit

public struct OGPResult {
    public var imageData: Data?
    public var siteName: String?
    public var title: String?

    public init(imageData: Data? = nil, siteName: String? = nil, title: String? = nil) {
        self.imageData = imageData
        self.siteName = siteName
        self.title = title
    }
}

public enum URLResolver {
    public static func resolveAll(_ urlString: String) async -> String {
        guard let url = URL(string: urlString) else { return urlString }

        let shortDomains = ["t.co", "bit.ly", "tinyurl.com", "ow.ly", "is.gd"]
        guard let host = url.host, shortDomains.contains(where: { host.hasSuffix($0) }) else {
            return urlString
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let finalURL = response.url {
                return finalURL.absoluteString
            }
        } catch {
            print("[URLResolver] Failed to resolve \(urlString): \(error.localizedDescription)")
        }

        return urlString
    }
}

public enum OGPFetcher {
    /// HTML ページの取得タイムアウト (秒)
    private static let htmlTimeout: TimeInterval = 15
    /// OG 画像の取得タイムアウト (秒)
    private static let imageTimeout: TimeInterval = 10
    /// OG 画像の最大ダウンロードサイズ (5 MB)
    private static let maxImageBytes = 5 * 1024 * 1024

    public static func fetch(from urlString: String) async -> OGPResult {
        guard let url = URL(string: urlString) else { return OGPResult() }
        do {
            var htmlRequest = URLRequest(url: url)
            htmlRequest.timeoutInterval = htmlTimeout
            let (data, _) = try await URLSession.shared.data(for: htmlRequest)
            guard let html = String(data: data, encoding: .utf8) else { return OGPResult() }

            let siteName = extractMetaContent(from: html, property: "og:site_name")
            let ogTitle = extractMetaContent(from: html, property: "og:title")

            var imageData: Data?
            if let imageURLString = extractMetaContent(from: html, property: "og:image") {
                let resolvedURL: String
                if imageURLString.hasPrefix("http") {
                    resolvedURL = imageURLString
                } else {
                    resolvedURL = URL(string: imageURLString, relativeTo: url)?.absoluteString ?? imageURLString
                }
                if let imageURL = URL(string: resolvedURL) {
                    imageData = try? await fetchImageWithLimit(from: imageURL)
                }
            }

            return OGPResult(imageData: imageData, siteName: siteName, title: ogTitle)
        } catch {
            print("[OGPFetcher] Failed to fetch from \(urlString): \(error.localizedDescription)")
            return OGPResult()
        }
    }

    /// 画像をストリーミング受信し、`maxImageBytes` を超えた時点でキャンセルする。
    /// 通信量自体を抑えることでモバイルデータの浪費を防ぐ。
    private static func fetchImageWithLimit(from url: URL) async throws -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = imageTimeout

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        // Content-Length が事前に分かる場合は早期に弾く
        if let httpResponse = response as? HTTPURLResponse,
           let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
           let length = Int(contentLength), length > maxImageBytes {
            print("[OGPFetcher] Image too large (Content-Length: \(length) bytes), skipping")
            return nil
        }

        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxImageBytes {
                print("[OGPFetcher] Image exceeded \(maxImageBytes) bytes during download, cancelling")
                return nil
            }
        }

        guard !data.isEmpty else { return nil }
        return downsizedJPEGData(data, maxDimension: 600)
    }

    private static func extractMetaContent(from html: String, property: String) -> String? {
        let patterns = [
            "property\\s*=\\s*\"\(property)\"[^>]*content\\s*=\\s*\"([^\"]+)\"",
            "content\\s*=\\s*\"([^\"]+)\"[^>]*property\\s*=\\s*\"\(property)\""
        ]
        for patternString in patterns {
            guard let regex = try? NSRegularExpression(pattern: patternString) else { continue }
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let captureRange = Range(match.range(at: 1), in: html) {
                return String(html[captureRange])
            }
        }
        return nil
    }
}
