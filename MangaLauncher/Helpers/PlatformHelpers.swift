import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - Cross-platform Image from Data

extension Data {
    func toSwiftUIImage() -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: self) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: self) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
}

// MARK: - Cross-platform Image Resize

func downsizedJPEGData(_ data: Data, maxDimension: CGFloat, compressionQuality: CGFloat = 0.7) -> Data? {
    #if canImport(UIKit)
    guard let uiImage = UIImage(data: data) else { return nil }
    let width = uiImage.size.width
    let height = uiImage.size.height
    let scale = min(maxDimension / width, maxDimension / height, 1.0)
    let newSize = CGSize(width: width * scale, height: height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let resizedImage = renderer.image { _ in
        uiImage.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return resizedImage.jpegData(compressionQuality: compressionQuality)
    #else
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let scale = min(maxDimension / width, maxDimension / height, 1.0)
    let newWidth = Int(width * scale)
    let newHeight = Int(height * scale)

    guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil, width: newWidth, height: newHeight,
              bitsPerComponent: 8, bytesPerRow: 0,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { return nil }

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

    guard let resizedImage = context.makeImage() else { return nil }

    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        mutableData, UTType.jpeg.identifier as CFString, 1, nil
    ) else { return nil }

    CGImageDestinationAddImage(
        destination, resizedImage,
        [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else { return nil }

    return mutableData as Data
    #endif
}

// MARK: - PasteButton Image Support

#if canImport(UIKit)
struct PasteImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
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

// MARK: - Cross-platform Colors

extension Color {
    static var platformBackground: Color {
        #if canImport(UIKit)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var platformGray5: Color {
        #if canImport(UIKit)
        Color(.systemGray5)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
}
