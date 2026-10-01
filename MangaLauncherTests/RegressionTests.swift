import Testing
import Foundation
import SwiftData
import UIKit
import LocalAuthentication
import CloudSyncKit
@testable import MangaLauncher

/// レビューで見つかった不具合の回帰テスト。
/// cloudKitDatabase: .none — アプリが iCloud 権限を持つため既定ではインメモリでも CloudKit ミラーリングが付き、
/// iCloud 未ログインのシミュレータではコンテナ破棄ごとに約100秒ブロックしていた。
@MainActor
private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
        for: MangaEntry.self, ReadingActivity.self, MangaComment.self, MangaLink.self, PublisherMetadata.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

    @Test func mutatingEntryDeletedElsewhereDoesNotCrash() throws {
        let (container, vm, staleEntry) = try setUp()
        // 他端末 (CloudKit) などで完全削除された
        let other = ModelContext(container)
        try other.delete(model: MangaEntry.self)
        try other.save()
        vm.refresh()
        vm.setPersonalRating(staleEntry, to: 3)
        #expect(try stored(MangaEntry.self, in: container).isEmpty)
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

/// CatchUp のスワイプ確定が遅延実行で実行時点の位置を読むため、連打・undo・リロードで
/// 見ていない作品が既読になっていた。
@Suite("CatchUpSession")
struct CatchUpSessionTests {
    private func session(_ names: [String]) -> CatchUpSession {
        CatchUpSession(items: names.map { MangaEntry(name: $0) })
    }

    @Test func doubleTapReadsOnlyCurrentCard() {
        var s = session(["A", "B", "C"])
        let first = s.beginSwipe()
        let second = s.beginSwipe() // 確定待ち中の2回目は無視
        let read = s.completeSwipe(.read)
        let again = s.completeSwipe(.read)
        #expect(first && !second)
        #expect(read?.name == "A")
        #expect(again == nil)
        #expect(s.currentIndex == 1)
        #expect(s.undoStack.count == 1)
    }

    @Test func busyWhilePending() {
        var s = session(["A", "B"])
        _ = s.beginSwipe()
        #expect(s.isBusy) // View はこの間 undo / 全部既読 を無効化する
        _ = s.completeSwipe(.skip)
        #expect(!s.isBusy)
    }

    @Test func reloadDuringPendingStillTargetsReservedCard() {
        var s = session(["A", "B", "C"])
        _ = s.beginSwipe()
        // 確定待ちの間にリロードで並びが変わった
        s.items = [s.items[1], s.items[2], s.items[0]]
        let read = s.completeSwipe(.read)
        #expect(read?.name == "A")
        #expect(s.items.map(\.name) == ["A", "B", "C"])
        #expect(s.currentIndex == 1)
    }

    @Test func reservedCardRemovedByReloadIsNotRead() {
        var s = session(["A", "B"])
        _ = s.beginSwipe()
        s.items.removeFirst() // 他端末で既読になり消えた
        let read = s.completeSwipe(.read)
        #expect(read == nil)
        #expect(s.currentIndex == 0)
    }
}

/// 重複チェックが非表示作品を見ておらず、生まれた重複を起動時 dedupe がゴミ箱を経由せず
/// 完全削除して、削除側のメモ・評価などが失われていた。重複時の保存失敗も無言だった。
@Suite("重複登録と起動時 dedupe")
@MainActor
struct DuplicateEntryTests {
    @Test func addRejectsDuplicateOfHiddenEntry() throws {
        let container = try makeContainer()
        let vm = MangaViewModel(modelContext: container.mainContext)
        vm.addEntry(name: "A", url: "https://a.example", days: [.monday], iconColor: "blue")
        vm.setHidden(try #require(vm.allEntries().first), isHidden: true)

        let added = vm.addEntry(name: "A2", url: "https://a.example", days: [.monday], iconColor: "blue")

        #expect(added == false)
        #expect(try stored(MangaEntry.self, in: container).count == 1)
    }

    @Test func updateReportsConflict() throws {
        let container = try makeContainer()
        let vm = MangaViewModel(modelContext: container.mainContext)
        vm.addEntry(name: "A", url: "https://a.example", days: [.monday], iconColor: "blue")
        vm.addEntry(name: "B", url: "https://b.example", days: [.monday], iconColor: "blue")
        let b = try #require(vm.allEntries().first { $0.name == "B" })

        let updated = vm.updateEntry(
            b, name: "B", url: "https://a.example", dayOfWeek: .monday, iconColor: "blue",
            isOneShot: false, publicationStatus: .active, readingState: .following, memo: "changed"
        )

        #expect(updated == false)
        #expect(b.memo == "")
    }

    @Test func dedupeSoftDeletesAndMergesLoser() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let kept = MangaEntry(name: "A", url: "https://a.example", dayOfWeek: .monday)
        kept.memo = "kept memo"
        let loser = MangaEntry(name: "A", url: "https://a.example", dayOfWeek: .monday)
        loser.memo = "loser memo"
        loser.personalRating = 5
        context.insert(kept)
        context.insert(loser)
        try context.save()

        let vm = MangaViewModel(modelContext: context)
        vm.runStartupMigrationsIfNeeded()

        let all = try stored(MangaEntry.self, in: container)
        #expect(all.count == 2) // 完全削除しない
        let active = try #require(all.first { $0.deletedAt == nil })
        #expect(all.filter { $0.deletedAt == nil }.count == 1)
        #expect(active.personalRating == 5)
        #expect(active.memo.contains("kept memo") && active.memo.contains("loser memo"))
    }
}

/// パスコード未設定の端末では認証が常に失敗し、非表示の作品・最近削除した項目に二度と入れなかった。
@Suite("BiometricAuthService")
struct BiometricAuthServiceTests {
    private final class NoPasscodeContext: LAContext {
        override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool { false }
    }

    @Test func allowsAccessWhenDeviceHasNoPasscode() async {
        #expect(await BiometricAuthService.authenticate(reason: "test", context: NoPasscodeContext()))
    }
}

/// 非表示・ゴミ箱の作品の既読がタイムライン/ヒートマップ日別一覧に作品名つきで出ていた。
/// 件数バッジも一覧から除外されるコメントまで数えていた。
@Suite("非表示・削除済み作品の可視性")
@MainActor
struct VisibilityTests {
    @Test func activitiesOfHiddenOrDeletedEntriesAreNotVisible() throws {
        let container = try makeContainer()
        let vm = MangaViewModel(modelContext: container.mainContext)
        for name in ["visible", "hidden", "deleted"] {
            vm.addEntry(name: name, url: "https://\(name).example", days: [.monday], iconColor: "blue")
        }
        let entries = Dictionary(uniqueKeysWithValues: vm.allEntries().map { ($0.name, $0) })
        for entry in entries.values { vm.markAsRead(entry) }
        vm.setHidden(try #require(entries["hidden"]), isHidden: true)
        vm.deleteEntry(try #require(entries["deleted"]))

        let visible = vm.allActivities().filter(vm.isActivityVisible).map(\.mangaName)
        #expect(visible == ["visible"])

        let purged = ReadingActivity(date: Date(), mangaName: "purged", mangaEntryID: UUID())
        #expect(vm.isActivityVisible(purged)) // 完全削除済みは記録の名前で表示し続ける
    }

    @Test func totalCountMatchesListedComments() {
        let entry = MangaEntry(name: "A")
        let comments = [
            MangaComment(mangaEntryID: entry.id, content: "shown"),
            MangaComment(mangaEntryID: UUID(), content: "hidden entry's"),
        ]
        #expect(ActivityBuilder.totalCount(entries: [entry], comments: comments)
            == ActivityBuilder.all(entries: [entry], comments: comments).count)
    }
}

/// 並び替え・曜日移動・既読処理の不整合。
@Suite("並び替えと次回更新日")
@MainActor
struct ReorderAndNextUpdateTests {
    /// テスト中に解放されると mainContext が無効になるため保持する
    private let container: ModelContainer

    init() throws {
        container = try makeContainer()
    }

    private func vmWith(_ specs: [(String, String)]) throws -> MangaViewModel {
        let vm = MangaViewModel(modelContext: container.mainContext)
        for (name, publisher) in specs {
            vm.addEntry(name: name, url: "https://\(name).example", days: [.monday], iconColor: "blue", publisher: publisher)
        }
        return vm
    }

    @Test func reorderUnderPublisherFilterMovesOnlyVisibleEntries() throws {
        let vm = try vmWith([("A", "J"), ("B", "M"), ("C", "J")])
        let visible = vm.fetchEntries(for: .monday).filter { $0.publisher == "J" } // [A, C]
        // フィルタ表示中に C を先頭へ
        vm.moveEntries(for: .monday, visible: visible, from: IndexSet(integer: 1), to: 0)
        #expect(vm.fetchEntries(for: .monday).map(\.name) == ["C", "B", "A"])
    }

    @Test func droppingOnSameDayKeepsNextUpdate() throws {
        let vm = try vmWith([("A", "")])
        let entry = try #require(vm.allEntries().first)
        let scheduled = Calendar.current.date(byAdding: .day, value: 14, to: Calendar.current.startOfDay(for: Date()))
        entry.nextExpectedUpdate = scheduled
        vm.moveEntryToDay(entry, to: .monday)
        #expect(entry.nextExpectedUpdate == scheduled)
    }

    @Test func biweeklyReadKeepsUpcomingReleaseDate() throws {
        let calendar = Calendar.current
        let entry = MangaEntry(name: "A", dayOfWeek: .monday, updateIntervalWeeks: 2)
        // 次の更新 (月曜) はまだ来ていない。休み週に前回分を遅れて読んだ
        let mostRecentMonday = MangaEntry.mostRecentOccurrence(of: .monday)
        let upcoming = try #require(calendar.date(byAdding: .day, value: 7, to: mostRecentMonday))
        entry.nextExpectedUpdate = upcoming
        entry.recordRead()
        #expect(entry.nextExpectedUpdate == upcoming)
    }

    @Test func pastScheduleAdvancesByIntervalKeepingPhase() throws {
        let calendar = Calendar.current
        let entry = MangaEntry(name: "A", dayOfWeek: .monday, updateIntervalWeeks: 2)
        let mostRecentMonday = MangaEntry.mostRecentOccurrence(of: .monday)
        entry.nextExpectedUpdate = calendar.date(byAdding: .day, value: -14, to: mostRecentMonday)
        entry.recordRead()
        #expect(entry.nextExpectedUpdate == calendar.date(byAdding: .day, value: 14, to: mostRecentMonday))
    }

    @Test func invalidIntervalDoesNotHang() {
        let entry = MangaEntry(name: "A", dayOfWeek: .monday, updateIntervalWeeks: 0)
        entry.nextExpectedUpdate = Date.distantPast.addingTimeInterval(86_400 * 365 * 1900)
        entry.recordRead()
        #expect((entry.nextExpectedUpdate ?? .distantPast) > Date())
    }

    @Test func incrementEpisodeAdvancesNextUpdateAndArchivesOneShot() throws {
        let vm = try vmWith([("A", ""), ("B", "")])
        let entries = vm.allEntries()
        let serial = try #require(entries.first { $0.name == "A" })
        vm.incrementEpisode(serial)
        #expect((serial.nextExpectedUpdate ?? .distantPast) > Date())

        let oneShot = try #require(entries.first { $0.name == "B" })
        oneShot.isOneShot = true
        vm.incrementEpisode(oneShot)
        #expect(oneShot.readingState == .archived)
    }
}

/// ライブラリのセクション: 掲載誌 5 誌以下だと統合/アイコン設定の画面に入れず、
/// 掲載誌名が固定セクション名と同じだと ForEach の ID が重複していた。
@Suite("LibrarySectionBuilder")
@MainActor
struct LibrarySectionBuilderTests {
    @Test func publisherManagementReachableWithFewPublishers() {
        let entry = MangaEntry(name: "A", publisher: "ジャンプ")
        let sections = LibrarySectionBuilder(allEntries: [entry]).build()
        #expect(sections.contains { $0.seeAll == .allPublishers })
    }

    @Test func sectionIDsAreUniqueEvenIfPublisherMatchesFixedTitle() {
        let unread = MangaEntry(name: "A", publisher: "未読") // 未読セクション + 掲載誌「未読」
        let sections = LibrarySectionBuilder(allEntries: [unread]).build()
        #expect(sections.filter { $0.title == "未読" }.count == 2)
        #expect(Set(sections.map(\.id)).count == sections.count)
    }
}

/// バックアップがフォーカス積読を含まず、更新間隔の不正値も検証していなかった。
@Suite("Backup")
@MainActor
struct BackupRegressionTests {
    @Test func roundTripKeepsFocusAndClampsInterval() throws {
        let source = try makeContainer()
        let vm = MangaViewModel(modelContext: source.mainContext)
        vm.addEntry(name: "A", url: "https://a.example", days: [.monday], iconColor: "blue", readingState: .backlog)
        let entry = try #require(vm.allEntries().first)
        vm.focus(entry)
        entry.updateIntervalWeeks = 0 // 壊れた値
        vm.save()
        let data = try #require(vm.exportBackupData())

        let target = try makeContainer()
        let restoredVM = MangaViewModel(modelContext: target.mainContext)
        _ = restoredVM.importBackupData(data)
        let restored = try #require(try stored(MangaEntry.self, in: target).first)
        #expect(restored.isFocused)
        #expect(restored.focusedAt != nil)
        #expect(restored.updateIntervalWeeks == 1)
    }
}

/// 起動時の同期待ちが CloudKit の setup 完了 (.idle) で抜け、import 前の古いデータに
/// migration/dedupe が走っていた。
@Suite("同期待ちの判定")
struct SyncSettleTests {
    @Test func keepsWaitingAfterSetupUntilImport() {
        #expect(!MangaLauncherApp.shouldStopWaitingForSync(status: .idle, sawSyncing: true, importCompleted: false, elapsed: 4))
        #expect(MangaLauncherApp.shouldStopWaitingForSync(status: .idle, sawSyncing: true, importCompleted: true, elapsed: 4))
    }

    @Test func stopsWhenSyncNeverStartsOrTimesOut() {
        #expect(MangaLauncherApp.shouldStopWaitingForSync(status: .idle, sawSyncing: false, importCompleted: false, elapsed: 3.2))
        #expect(MangaLauncherApp.shouldStopWaitingForSync(status: .syncing, sawSyncing: true, importCompleted: false, elapsed: 10))
        #expect(MangaLauncherApp.shouldStopWaitingForSync(status: .notAvailable, sawSyncing: false, importCompleted: false, elapsed: 0.2))
    }
}

/// 編集画面の次回更新日候補が 8 回分固定で、2ヶ月ごと以上の作品は保存するだけで次回更新日が上書きされた。
@Suite("EditEntryView 次回更新日候補")
struct NextUpdateCandidatesTests {
    @Test func coversDateSetByReadingLongIntervalEntry() throws {
        let entry = MangaEntry(name: "A", dayOfWeek: .monday, updateIntervalWeeks: 8)
        entry.recordRead()
        let saved = try #require(entry.nextExpectedUpdate)
        let candidates = EditEntryView.nextUpdateCandidates(for: .monday, intervalWeeks: 8)
        #expect(candidates.contains(saved))
    }
}
