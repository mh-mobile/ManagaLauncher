import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 画像から支配的な色を抽出し、Apple Music風の背景グラデーションを生成する
enum ImageColorExtractor {

    struct GradientColors: Equatable {
        let top: Color
        let bottom: Color
    }

    /// 画像データから背景グラデーション用の2色を抽出する
    static func extractGradient(from data: Data) -> GradientColors? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return nil }

        let size = 40
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let pixelData = context.data else { return nil }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: size * size * 4)

        let top = averageColor(pixels: pixels, size: size, rowRange: 0..<(size / 3))
        let bottom = averageColor(pixels: pixels, size: size, rowRange: (size * 2 / 3)..<size)

        return GradientColors(
            top: Color(red: top.r * 0.6, green: top.g * 0.6, blue: top.b * 0.6),
            bottom: Color(red: bottom.r * 0.4, green: bottom.g * 0.4, blue: bottom.b * 0.4)
        )
        #else
        return nil
        #endif
    }

    private static func averageColor(
        pixels: UnsafeMutablePointer<UInt8>,
        size: Int,
        rowRange: Range<Int>
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0

        for y in rowRange {
            for x in 0..<size {
                let offset = (y * size + x) * 4
                totalR += CGFloat(pixels[offset]) / 255
                totalG += CGFloat(pixels[offset + 1]) / 255
                totalB += CGFloat(pixels[offset + 2]) / 255
                count += 1
            }
        }

        guard count > 0 else { return (0, 0, 0) }
        return (totalR / count, totalG / count, totalB / count)
    }
}
