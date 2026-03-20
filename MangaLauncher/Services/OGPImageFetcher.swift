import Foundation

enum OGPImageFetcher {
    static func fetchOGPImageData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            guard let imageURLString = extractOGPImageURL(from: html, baseURL: url) else { return nil }
            guard let imageURL = URL(string: imageURLString) else { return nil }
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            return downsizedJPEGData(imageData, maxDimension: 600)
        } catch {
            return nil
        }
    }

    private static func extractOGPImageURL(from html: String, baseURL: URL) -> String? {
        // Try pattern: <meta property="og:image" content="...">
        let patterns = [
            #/<meta[^>]*property\s*=\s*"og:image"[^>]*content\s*=\s*"([^"]+)"/#,
            #/<meta[^>]*content\s*=\s*"([^"]+)"[^>]*property\s*=\s*"og:image"/#
        ]
        for pattern in patterns {
            if let match = html.firstMatch(of: pattern) {
                let urlString = String(match.1)
                if urlString.hasPrefix("http") {
                    return urlString
                }
                // Handle relative URLs
                return URL(string: urlString, relativeTo: baseURL)?.absoluteString
            }
        }
        return nil
    }
}
