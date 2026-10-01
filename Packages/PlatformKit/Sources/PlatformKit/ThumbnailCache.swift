import SwiftUI
import ImageIO

#if canImport(UIKit)
import UIKit

/// Data → デコード済み UIImage のプロセス内キャッシュ。
/// セルの body 内で毎回 `UIImage(data:)` フルデコードが走るのを避ける。
/// キーはコンテンツアドレス方式(呼び出し側ID + サイズバケット + バイト数 + 内容ハッシュ)のため、
/// 画像編集や CloudKit 同期で imageData が差し替わると自動的に別キーになり、明示的な無効化は不要。
public final class ThumbnailCache: @unchecked Sendable {
    public static let shared = ThumbnailCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 100 * 1024 * 1024 // cost = ピクセル数 × 4byte 換算で約100MB
        return cache
    }()

    init() {
        // デコード済みビットマップは再生成できるので、メモリ警告時は全破棄して常駐量を解放する
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { [cache] _ in
            cache.removeAllObjects()
        }
    }

    public func image(id: String, data: Data, fillPixelSize: CGFloat?) -> UIImage? {
        let key = cacheKey(id: id, data: data, fillPixelSize: fillPixelSize) as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = decode(data, fillPixelSize: fillPixelSize) else { return nil }
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        cache.setObject(image, forKey: key, cost: Int(pixelWidth * pixelHeight) * 4)
        return image
    }

    private func cacheKey(id: String, data: Data, fillPixelSize: CGFloat?) -> String {
        let bucket = fillPixelSize.map { String(Int($0)) } ?? "full"
        return "\(id)|\(bucket)|\(data.count)|\(contentToken(data))"
    }

    /// 先頭/末尾 1KB の FNV-1a ハッシュ。`Data.hashValue` は先頭 80 バイトしか見ず
    /// JPEG ヘッダは酷似するため、内容変化の検出には使えない。
    private func contentToken(_ data: Data) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ bytes: Data) {
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* 0x1_0000_0000_01b3
            }
        }
        mix(data.prefix(1024))
        if data.count > 1024 {
            mix(data.suffix(1024))
        }
        return hash
    }

    /// ImageIO でダウンサンプルしつつ即時デコード。
    /// fillPixelSize 指定時は短辺がそのピクセル数を満たすサイズ、nil は長辺 `fullMaxPixelSize` に収める。
    /// (旧バージョンは画面スケールの不具合で 1800px 級の画像を保存していたため、nil でも原寸デコードしない)
    private func decode(_ data: Data, fillPixelSize: CGFloat?) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let maxPixelSize: CGFloat
        if let fillPixelSize {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
            let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
            maxPixelSize = Self.thumbnailMaxPixelSize(width: width, height: height, fillPixelSize: fillPixelSize)
        } else {
            maxPixelSize = Self.fullMaxPixelSize
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

extension Data {
    /// `toSwiftUIImage()` のキャッシュ付き版。
    /// - Parameters:
    ///   - id: 呼び出し側の安定ID (例: `entry.id.uuidString`)
    ///   - fillPixelSize: 正方形枠に `scaledToFill` する小さい行サムネイルなら `ThumbnailCache.smallFillPixelSize`。
    ///     短辺がこのピクセル数を満たすようダウンサンプルする (原寸は超えない)。
    ///     nil は長辺 `fullMaxPixelSize` に収めてデコード (アスペクト比がレイアウトを決めるグリッドセル用)
    public func toCachedSwiftUIImage(id: String, fillPixelSize: CGFloat? = nil) -> Image? {
        guard let uiImage = ThumbnailCache.shared.image(id: id, data: self, fillPixelSize: fillPixelSize) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

#else

/// UIKit のないプラットフォーム用のプレースホルダ (定数参照だけ揃える)。
public enum ThumbnailCache {}

extension Data {
    /// UIKit のないプラットフォームではキャッシュせず既存経路にフォールバック。
    public func toCachedSwiftUIImage(id: String, fillPixelSize: CGFloat? = nil) -> Image? {
        toSwiftUIImage()
    }
}

#endif

extension ThumbnailCache {
    /// 表示サイズ ≤44pt の正方形行サムネイル用 (44pt @3x = 132px)。
    public static let smallFillPixelSize: CGFloat = 132

    /// fillPixelSize 未指定 (グリッド/カード) 時の長辺上限。最大の表示は CatchUp カード 600pt @2x (iPad)。
    public static let fullMaxPixelSize: CGFloat = 1200

    /// `kCGImageSourceThumbnailMaxPixelSize` は長辺の上限なので、正方形枠へ `scaledToFill` すると
    /// 横長/縦長画像の短辺が不足して拡大(ぼやけ)が起きる。短辺が `fillPixelSize` を満たす長辺値を返す。
    /// 原寸を超える値は返さない (サイズ不明時は fillPixelSize)。
    static func thumbnailMaxPixelSize(width: Double, height: Double, fillPixelSize: CGFloat) -> CGFloat {
        let shortSide = min(width, height)
        let longSide = max(width, height)
        guard shortSide > 0 else { return fillPixelSize }
        return CGFloat(min(longSide, (Double(fillPixelSize) * longSide / shortSide).rounded(.up)))
    }
}
