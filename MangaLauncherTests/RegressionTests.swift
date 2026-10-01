import Testing
import Foundation
import SwiftData
import UIKit
@testable import MangaLauncher

/// レビューで見つかった不具合の回帰テスト。
@MainActor
private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
        for: MangaEntry.self, ReadingActivity.self, MangaComment.self, MangaLink.self, PublisherMetadata.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

/// 別コンテキストから永続化済みの値を読む (VM のキャッシュや登録済みオブジェクトを経由しない)
@MainActor
private func stored<T: PersistentModel>(_ type: T.Type, in container: ModelContainer) throws -> [T] {
    try ModelContext(container).fetch(FetchDescriptor<T>())
}

/// フォアグラウンド復帰ごとの refresh() で modelContext が差し替わった後、
/// View が保持している旧コンテキストのオブジェクトへの変更が保存されなかった (P1-1)。
@Suite("refresh() をまたいだ変更の永続化")
@MainActor
struct RefreshAcrossContextTests {

    /// エントリを作り、View が保持する想定の参照を取ってから refresh() で差し替える
    private func setUp() throws -> (ModelContainer, MangaViewModel, MangaEntry) {
        let container = try makeContainer()
        let vm = MangaViewModel(modelContext: container.mainContext)
        vm.addEntry(name: "A", url: "https://a.example", days: [.monday], iconColor: "blue")
        vm.refresh()
        let entry = try #require(vm.allEntries().first)
        vm.refresh()
        return (container, vm, entry)
    }

    @Test func commitPendingDeletesPersists() throws {
        let (container, vm, entry) = try setUp()
        vm.queueDelete(entry)
        vm.commitPendingDeletes()
        #expect(try stored(MangaEntry.self, in: container).first?.deletedAt != nil)
    }

    @Test func permanentlyDeletePersists() throws {
        let (container, vm, entry) = try setUp()
        vm.deleteEntry(entry)
        vm.permanentlyDelete(entry)
        #expect(try stored(MangaEntry.self, in: container).isEmpty)
    }

    @Test func restorePersists() throws {
        let container = try makeContainer()
        let vm = MangaViewModel(modelContext: container.mainContext)
        vm.addEntry(name: "A", url: "https://a.example", days: [.monday], iconColor: "blue")
        vm.deleteEntry(try #require(vm.allEntries().first))
        vm.refresh()
        // 「最近削除した項目」画面が保持する参照
        let deleted = try #require(vm.deletedEntries().first)
        vm.refresh()
        vm.restoreEntry(deleted)
        #expect(try stored(MangaEntry.self, in: container).first?.deletedAt == nil)
    }

    @Test func staleObjectUpdateDoesNotConflict() throws {
        let (container, vm, staleEntry) = try setUp()
        // 新しいコンテキスト側で同じ行を先に更新・保存しておく
        let fresh = try #require(vm.allEntries().first)
        vm.setPersonalRating(fresh, to: 4)
        // 旧コンテキストのオブジェクトで別の属性を更新
        vm.incrementEpisode(staleEntry)
        #expect(vm.lastError == nil)
        let saved = try #require(try stored(MangaEntry.self, in: container).first)
        #expect(saved.currentEpisode == 1)
        #expect(saved.personalRating == 4)
    }

    @Test func incrementEpisodePersists() throws {
        let (container, vm, entry) = try setUp()
        vm.incrementEpisode(entry)
        #expect(try stored(MangaEntry.self, in: container).first?.currentEpisode == 1)
    }

    @Test func updateCommentPersists() throws {
        let (container, vm, entry) = try setUp()
        vm.addComment(entry, content: "before")
        let comment = try #require(vm.fetchComments(for: entry).first)
        vm.refresh()
        vm.updateComment(comment, content: "after")
        #expect(try stored(MangaComment.self, in: container).first?.content == "after")
    }

    @Test func commitPendingCommentDeletesPersists() throws {
        let (container, vm, entry) = try setUp()
        vm.addComment(entry, content: "c")
        let comment = try #require(vm.fetchComments(for: entry).first)
        vm.refresh()
        vm.queueDeleteComment(comment)
        vm.commitPendingCommentDeletes()
        #expect(try stored(MangaComment.self, in: container).isEmpty)
    }

    @Test func deleteLinkPersists() throws {
        let (container, vm, entry) = try setUp()
        vm.addLink(entry, linkType: .other, title: "t", url: "https://l.example")
        let link = try #require(vm.fetchLinks(for: entry).first)
        vm.refresh()
        vm.deleteLink(link)
        #expect(try stored(MangaLink.self, in: container).isEmpty)
    }
}

/// 掲載誌アイコンの整形が画面スケール分大きく、EXIF 回転のある写真で歪み、透過が黒くなっていた。
@Suite("PublisherIconService.cropAndResize")
@MainActor
struct PublisherIconCropTests {
    /// 左半分が赤・右半分が青の 400x200 画像
    private func halfRedHalfBlue(orientation: UIImage.Orientation) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let base = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 200, y: 0, width: 200, height: 200))
        }
        return UIImage(cgImage: base.cgImage!, scale: 1, orientation: orientation)
    }

    private func rgb(_ image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (pixel[0], pixel[1], pixel[2])
    }

    @Test func outputIsTargetPixels() throws {
        let data = try #require(PublisherIconService.cropAndResize(halfRedHalfBlue(orientation: .up)))
        let image = try #require(UIImage(data: data)?.cgImage)
        #expect(image.width == 256 && image.height == 256)
    }

    @Test func respectsExifOrientation() throws {
        // .right (時計回り 90°) で表示上は 200x400 の縦長、上半分が赤・下半分が青
        let data = try #require(PublisherIconService.cropAndResize(halfRedHalfBlue(orientation: .right)))
        let image = try #require(UIImage(data: data)?.cgImage)
        #expect(image.width == image.height)
        let top = rgb(image, x: 128, y: 20)
        let bottom = rgb(image, x: 128, y: 235)
        #expect(top.r > 200 && top.b < 60)
        #expect(bottom.b > 200 && bottom.r < 60)
    }
}

/// 全データ削除が削除待ちキュー/タイマーを残し (削除済みオブジェクトへの書き込み)、MangaLink も残していた。
@Suite("deleteAllEntries")
@MainActor
struct DeleteAllEntriesTests {
    @Test func clearsPendingDeletesAndLinks() throws {
        let container = try makeContainer()
        let vm = MangaViewModel(modelContext: container.mainContext)
        vm.addEntry(name: "A", url: "https://a.example", days: [.monday], iconColor: "blue")
        vm.addEntry(name: "B", url: "https://b.example", days: [.monday], iconColor: "blue")
        let entries = vm.allEntries()
        vm.addLink(entries[0], linkType: .other, title: "t", url: "https://l.example")
        vm.addComment(entries[0], content: "c")
        vm.queueDelete(entries[1])
        vm.queueDeleteComment(try #require(vm.fetchComments(for: entries[0]).first))

        vm.deleteAllEntries()

        #expect(vm.pendingDeleteEntries.isEmpty)
        #expect(vm.pendingDeleteComments.isEmpty)
        #expect(vm.deleteTimer == nil)
        #expect(vm.commentDeleteTimer == nil)
        #expect(try stored(MangaLink.self, in: container).isEmpty)
        #expect(try stored(MangaEntry.self, in: container).isEmpty)
    }
}
