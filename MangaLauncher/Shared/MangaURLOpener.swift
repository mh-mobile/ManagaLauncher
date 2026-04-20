import SwiftUI

struct BrowserContext: Identifiable {
    let id = UUID()
    let url: URL
    let entryName: String?
    let entryPublisher: String?
    let entryImageData: Data?

    init(url: URL, entryName: String? = nil, entryPublisher: String? = nil, entryImageData: Data? = nil) {
        self.url = url
        self.entryName = entryName
        self.entryPublisher = entryPublisher
        self.entryImageData = entryImageData
    }
}

struct MangaURLOpener {
    let browserMode: String
    let openURL: OpenURLAction
    var onBrowserContext: ((BrowserContext) -> Void)?

    func open(_ urlString: String, entry: MangaEntry? = nil) {
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit)
        let isWebURL = url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https"
        if (browserMode == "inApp" || browserMode == "overlay") && isWebURL {
            onBrowserContext?(BrowserContext(
                url: url,
                entryName: entry?.name,
                entryPublisher: entry?.publisher,
                entryImageData: entry?.imageData
            ))
        } else {
            openURL(url)
        }
        #else
        openURL(url)
        #endif
    }
}
