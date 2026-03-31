import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - Color ↔ Hex

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    public func toHex() -> String {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "007AFF"
        }
        #elseif canImport(AppKit)
        guard let converted = NSColor(self).usingColorSpace(.sRGB),
              let components = converted.cgColor.components, components.count >= 3 else {
            return "007AFF"
        }
        #endif
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - Image from Data

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

// MARK: - Image Resize

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
