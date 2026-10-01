import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - Cross-platform Image from Data

extension Data {
    public func toSwiftUIImage() -> Image? {
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

/// 長辺を `maxDimension` ピクセル以下に縮小した JPEG を返す (拡大はしない)。
/// - ImageIO の縮小デコードを使うので、巨大な寸法の画像でもフルサイズのビットマップを作らない
/// - EXIF の向きを反映し、透過部分は白で塗る (JPEG は透過を持てず黒になるため)
/// - 出力はピクセル単位。`UIGraphicsImageRenderer` の既定 format は画面スケール (3x) で描画し
///   指定の 3 倍の解像度になっていたため使わない
public func downsizedJPEGData(_ data: Data, maxDimension: CGFloat, compressionQuality: CGFloat = 0.7) -> Data? {
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return opaqueJPEGData(image, compressionQuality: compressionQuality)
}

/// CGImage を白背景に描いて JPEG 化する。
private func opaqueJPEGData(_ image: CGImage, compressionQuality: CGFloat) -> Data? {
    let width = image.width
    let height = image.height
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil, width: width, height: height,
              bitsPerComponent: 8, bytesPerRow: 0,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else { return nil }
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(rect)
    context.interpolationQuality = .high
    context.draw(image, in: rect)
    guard let rendered = context.makeImage() else { return nil }

    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        mutableData, UTType.jpeg.identifier as CFString, 1, nil
    ) else { return nil }
    CGImageDestinationAddImage(
        destination, rendered,
        [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else { return nil }
    return mutableData as Data
}
