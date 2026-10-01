import Testing
import Foundation
import SwiftData
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
