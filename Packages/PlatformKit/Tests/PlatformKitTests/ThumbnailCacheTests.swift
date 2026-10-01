import Testing
import Foundation
@testable import PlatformKit
#if canImport(UIKit)
import UIKit
#endif

struct ThumbnailCacheTests {
    @Test func landscapeKeepsShortSideForFill() {
        // OGP 画像 (600x314) を 132px 正方形に fill しても短辺が不足しないこと
        let longSide = ThumbnailCache.thumbnailMaxPixelSize(width: 600, height: 314, fillPixelSize: 132)
        #expect(longSide == 253)
        #expect(longSide * 314 / 600 >= 132)
    }

    @Test func portraitKeepsShortSideForFill() {
        let longSide = ThumbnailCache.thumbnailMaxPixelSize(width: 600, height: 850, fillPixelSize: 132)
        #expect(longSide * 600 / 850 >= 132)
    }

    @Test func neverExceedsOriginal() {
        #expect(ThumbnailCache.thumbnailMaxPixelSize(width: 100, height: 50, fillPixelSize: 132) == 100)
    }

    @Test func unknownSizeFallsBackToFill() {
        #expect(ThumbnailCache.thumbnailMaxPixelSize(width: 0, height: 0, fillPixelSize: 132) == 132)
    }

    #if canImport(UIKit)
    private func jpeg(width: CGFloat, height: CGFloat, color: UIColor) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.7)!
    }

    @Test(arguments: [(600.0, 314.0), (600.0, 850.0)])
    func decodedSmallThumbnailFillsSquare(width: Double, height: Double) throws {
        let cache = ThumbnailCache()
        let data = jpeg(width: width, height: height, color: .red)
        let image = try #require(
            cache.image(id: "thumb", data: data, fillPixelSize: ThumbnailCache.smallFillPixelSize)
        )
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        #expect(min(pixelWidth, pixelHeight) >= ThumbnailCache.smallFillPixelSize)
        #expect(max(pixelWidth, pixelHeight) < max(width, height))
    }

    @Test func fullPathCapsLegacyOversizedImages() throws {
        // 旧バージョンが画面スケールの不具合で保存した 1800px 級の画像
        let data = jpeg(width: 1800, height: 2550, color: .red)
        let image = try #require(ThumbnailCache().image(id: "big", data: data, fillPixelSize: nil))
        #expect(max(image.size.width, image.size.height) * image.scale == ThumbnailCache.fullMaxPixelSize)
    }

    @Test func cacheHitContentChangeAndMemoryWarning() throws {
        let cache = ThumbnailCache()
        let red = jpeg(width: 200, height: 300, color: .red)
        let first = try #require(cache.image(id: "e", data: red, fillPixelSize: nil))
        #expect(cache.image(id: "e", data: red, fillPixelSize: nil) === first)

        let blue = jpeg(width: 200, height: 300, color: .blue)
        #expect(cache.image(id: "e", data: blue, fillPixelSize: nil) !== first)

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #expect(cache.image(id: "e", data: red, fillPixelSize: nil) !== first)
    }
    #endif
}
