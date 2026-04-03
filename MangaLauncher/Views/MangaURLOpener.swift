import SwiftUI

struct MangaURLOpener {
    let browserMode: String
    let openURL: OpenURLAction
    var onSafariURL: ((URL) -> Void)?

    func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit)
        let isWebURL = url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https"
        if browserMode == "inApp" && isWebURL {
            onSafariURL?(url)
        } else {
            openURL(url)
        }
        #else
        openURL(url)
        #endif
    }
}
