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
    var onSafariURL: ((URL) -> Void)?
    var onQuickView: ((BrowserContext) -> Void)?
    var entryLookup: ((String) -> (name: String?, publisher: String?, imageData: Data?)?)?

    func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit)
        let isWebURL = url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https"
        if (browserMode == "quickView" || browserMode == "overlay") && isWebURL {
            let info = entryLookup?(urlString)
            let ctx = BrowserContext(url: url, entryName: info?.name, entryPublisher: info?.publisher, entryImageData: info?.imageData)
            onQuickView?(ctx)
        } else if browserMode == "inApp" && isWebURL {
            onSafariURL?(url)
        } else {
            openURL(url)
        }
        #else
        openURL(url)
        #endif
    }
}
