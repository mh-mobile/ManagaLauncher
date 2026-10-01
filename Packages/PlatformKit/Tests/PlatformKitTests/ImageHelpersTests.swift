import Testing
import Foundation
import ImageIO
@testable import PlatformKit
#if canImport(UIKit)
import UIKit

struct ImageHelpersTests {
    private func pngData(width: CGFloat, height: CGFloat, opaque: Bool = true) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            if opaque {
                UIColor.red.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
        }.pngData()!
    }

    private func decoded(_ data: Data) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    @Test func outputIsInPixelsNotScreenPoints() throws {
        let output = try #require(downsizedJPEGData(pngData(width: 1000, height: 500), maxDimension: 600))
        let image = try decoded(output)
        #expect(image.width == 600)
        #expect(image.height == 300)
    }

    @Test func doesNotUpscale() throws {
        let output = try #require(downsizedJPEGData(pngData(width: 100, height: 50), maxDimension: 600))
        #expect(try decoded(output).width == 100)
    }

    @Test func transparentAreaBecomesWhite() throws {
        let output = try #require(downsizedJPEGData(pngData(width: 10, height: 10, opaque: false), maxDimension: 600))
        let pixel = UIImage(data: output)!.cgImage!.dataProvider!.data! as Data
        // 先頭ピクセル (RGB) が白に近いこと (旧実装は黒)
        #expect(pixel[0] > 240 && pixel[1] > 240 && pixel[2] > 240)
    }
}
#endif
