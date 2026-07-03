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

    public func image(id: String, data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        let key = cacheKey(id: id, data: data, maxPixelSize: maxPixelSize) as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = decode(data, maxPixelSize: maxPixelSize) else { return nil }
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        cache.setObject(image, forKey: key, cost: Int(pixelWidth * pixelHeight) * 4)
        return image
    }

    private func cacheKey(id: String, data: Data, maxPixelSize: CGFloat?) -> String {
        let bucket = maxPixelSize.map { String(Int($0)) } ?? "full"
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

    /// maxPixelSize 指定時は ImageIO でダウンサンプルしつつ即時デコード。
    /// nil はフルサイズデコード (保存時に 600px へ縮小済みのデータをそのまま使う)。
    private func decode(_ data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        guard let maxPixelSize else { return UIImage(data: data) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

extension ThumbnailCache {
    /// 表示サイズ ≤44pt の行サムネイル用バケット (44pt @3x = 132px < 160px)。
    public static let smallMaxPixelSize: CGFloat = 160
}

extension Data {
    /// `toSwiftUIImage()` のキャッシュ付き版。デコード結果を再利用するだけで描画結果は同一。
    /// - Parameters:
    ///   - id: 呼び出し側の安定ID (例: `entry.id.uuidString`)
    ///   - maxPixelSize: 小さい行サムネイル表示なら `ThumbnailCache.smallMaxPixelSize`。
    ///     nil はフルサイズデコード (アスペクト比がレイアウトを決めるグリッドセル用)
    public func toCachedSwiftUIImage(id: String, maxPixelSize: CGFloat? = nil) -> Image? {
        guard let uiImage = ThumbnailCache.shared.image(id: id, data: self, maxPixelSize: maxPixelSize) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

#else

/// UIKit のないプラットフォーム用のプレースホルダ (定数参照だけ揃える)。
public enum ThumbnailCache {
    public static let smallMaxPixelSize: CGFloat = 160
}

extension Data {
    /// UIKit のないプラットフォームではキャッシュせず既存経路にフォールバック。
    public func toCachedSwiftUIImage(id: String, maxPixelSize: CGFloat? = nil) -> Image? {
        toSwiftUIImage()
    }
}

#endif
