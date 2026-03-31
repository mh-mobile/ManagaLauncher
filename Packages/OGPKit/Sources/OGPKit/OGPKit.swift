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

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let finalURL = response.url {
                return finalURL.absoluteString
            }
        } catch {}

        return urlString
    }
}

public enum OGPFetcher {
    public static func fetch(from urlString: String) async -> OGPResult {
        guard let url = URL(string: urlString) else { return OGPResult() }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
                if let imageURL = URL(string: resolvedURL),
                   let (imgData, _) = try? await URLSession.shared.data(from: imageURL) {
                    imageData = downsizedJPEGData(imgData, maxDimension: 600)
                }
            }

            return OGPResult(imageData: imageData, siteName: siteName, title: ogTitle)
        } catch {
            return OGPResult()
        }
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
