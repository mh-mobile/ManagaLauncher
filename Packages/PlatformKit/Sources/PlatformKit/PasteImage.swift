#if canImport(UIKit)
import SwiftUI
import UniformTypeIdentifiers

public struct PasteImage: Transferable {
    public let data: Data

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .png) { data in
            PasteImage(data: data)
        }
        DataRepresentation(importedContentType: .jpeg) { data in
            PasteImage(data: data)
        }
        DataRepresentation(importedContentType: .tiff) { data in
            PasteImage(data: data)
        }
    }
}
#endif
