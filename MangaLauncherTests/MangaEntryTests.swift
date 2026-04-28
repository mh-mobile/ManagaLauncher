//
//  MangaEntryTests.swift
//  MangaLauncherTests
//
//  2 軸状態モデル (PublicationStatus × ReadingState) と invariant のテスト。
//

import Testing
import Foundation
import SwiftData
@testable import MangaLauncher

@Suite("MangaEntry.isRead")
struct MangaEntryIsReadTests {

    private func makeEntry(
        publication: PublicationStatus = .active,
        reading: ReadingState = .following,
        isOneShot: Bool = false,
        lastReadDate: Date? = nil
    ) -> MangaEntry {
        let e = MangaEntry(name: "x")
        e.publicationStatus = publication
        e.readingState = reading
        e.isOneShot = isOneShot
        e.lastReadDate = lastReadDate
        return e
    }

    @Test("読了 (archived) は常に既読")
    func archivedIsAlwaysRead() {
        let e = makeEntry(reading: .archived, lastReadDate: nil)
        #expect(e.isRead == true)
    }

    @Test("休載中は常に既読扱い")
    func hiatusIsAlwaysRead() {
        let e = makeEntry(publication: .hiatus, lastReadDate: nil)
        #expect(e.isRead == true)
    }

    @Test("完結は一度読んだら既読のまま")
    func finishedStaysReadAfterOnce() {
        let neverRead = makeEntry(publication: .finished, lastReadDate: nil)
        #expect(neverRead.isRead == false)

        let readOnce = makeEntry(publication: .finished, lastReadDate: Date(timeIntervalSince1970: 1_000_000))
        #expect(readOnce.isRead == true)
    }

    @Test("読み切りは一度読んだら既読")
    func oneShotReadOnce() {
        let notYet = makeEntry(isOneShot: true, lastReadDate: nil)
        #expect(notYet.isRead == false)

        let read = makeEntry(isOneShot: true, lastReadDate: Date())
        #expect(read.isRead == true)
    }
}

@Suite("MangaEntry.normalizeOneShotInvariants")
struct MangaEntryInvariantsTests {

    @Test("読み切り時は publicationStatus が active に強制")
    func oneShotForcesActive() {
        let e = MangaEntry(name: "x")
        e.isOneShot = true
        e.publicationStatus = .hiatus
        e.readingState = .following

        e.normalizeOneShotInvariants()

        #expect(e.publicationStatus == .active)
    }

    @Test("読み切り時は backlog が following に矯正")
    func oneShotForbidsBacklog() {
        let e = MangaEntry(name: "x")
        e.isOneShot = true
        e.publicationStatus = .active
        e.readingState = .backlog

        e.normalizeOneShotInvariants()

        #expect(e.readingState == .following)
    }

    @Test("連載 (isOneShot=false) では何も変更されない")
    func serialUnchanged() {
        let e = MangaEntry(name: "x")
        e.isOneShot = false
        e.publicationStatus = .hiatus
        e.readingState = .backlog

        e.normalizeOneShotInvariants()

        #expect(e.publicationStatus == .hiatus)
        #expect(e.readingState == .backlog)
    }
}

@Suite("MangaEntry.migrateLegacyStateIfNeeded")
struct MangaEntryMigrationTests {

    @Test("isCompleted=true は archived に移行")
    func completedMapsToArchived() {
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 0
        e.isCompleted = true

        e.migrateLegacyStateIfNeeded()

        #expect(e.readingState == .archived)
        #expect(e.publicationStatus == .active)
        #expect(e.stateMigrationVersion == 1)
    }

    @Test("isBacklog + isOnHiatus は backlog × hiatus に")
    func backlogAndHiatus() {
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 0
        e.isBacklog = true
        e.isOnHiatus = true

        e.migrateLegacyStateIfNeeded()

        #expect(e.readingState == .backlog)
        #expect(e.publicationStatus == .hiatus)
    }

    @Test("isOnHiatus 単独は following × hiatus")
    func hiatusOnly() {
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 0
        e.isOnHiatus = true

        e.migrateLegacyStateIfNeeded()

        #expect(e.readingState == .following)
        #expect(e.publicationStatus == .hiatus)
    }

    @Test("すべて false は デフォルト (following × active)")
    func defaultState() {
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 0

        e.migrateLegacyStateIfNeeded()

        #expect(e.readingState == .following)
        #expect(e.publicationStatus == .active)
    }

    @Test("stateMigrationVersion=1 は二重移行されない")
    func idempotent() {
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 1
        e.publicationStatus = .finished
        e.isCompleted = false // もし移行が走ったら archived にならない

        e.migrateLegacyStateIfNeeded()

        #expect(e.publicationStatus == .finished) // 変わらない
    }

    @Test("CloudKit 同期で来た新フィールドを上書きしない (legacy 全 false の場合)")
    func preservesCloudSyncedNewState() {
        // 別端末で .finished に設定された値が cloud から同期されてきた状態を想定
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 0
        e.publicationStatus = .finished
        e.readingState = .archived
        // legacy フィールドはすべて false (cloud 経由なので未設定)

        e.migrateLegacyStateIfNeeded()

        // 値は保持され、version だけ進む
        #expect(e.publicationStatus == .finished)
        #expect(e.readingState == .archived)
        #expect(e.stateMigrationVersion == 1)
    }

    @Test("CloudKit 同期で来た .backlog を上書きしない")
    func preservesBacklogState() {
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 0
        e.readingState = .backlog
        // publicationStatus はデフォルト .active (rawValue=0) のまま

        e.migrateLegacyStateIfNeeded()

        #expect(e.readingState == .backlog)
        #expect(e.stateMigrationVersion == 1)
    }

    @Test("CloudKit 同期で来た .hiatus を上書きしない")
    func preservesHiatusStatus() {
        let e = MangaEntry(name: "x")
        e.stateMigrationVersion = 0
        e.publicationStatus = .hiatus
        // readingState はデフォルト .following (rawValue=0) のまま

        e.migrateLegacyStateIfNeeded()

        #expect(e.publicationStatus == .hiatus)
        #expect(e.stateMigrationVersion == 1)
    }
}

@Suite("MangaViewModel.findEntries – duplicate ID regression")
struct MangaViewModelFindEntriesTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: MangaEntry.self, ReadingActivity.self, MangaComment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("同一 UUID のエントリが複数存在してもクラッシュしない")
    @MainActor
    func findEntriesWithDuplicateIDsDoesNotCrash() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let sharedID = UUID()
        let entry1 = MangaEntry(id: sharedID, name: "Entry A")
        let entry2 = MangaEntry(id: sharedID, name: "Entry B")
        context.insert(entry1)
        context.insert(entry2)
        try context.save()

        let vm = MangaViewModel(modelContext: context)
        let result = vm.findEntries(by: [sharedID])

        // クラッシュせず辞書が返り、重複は先勝ちで 1 件に集約される
        #expect(result.count == 1)
        #expect(result[sharedID] != nil)
    }

    @Test("重複なしの場合は全件返る")
    @MainActor
    func findEntriesWithUniqueIDs() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let id1 = UUID()
        let id2 = UUID()
        context.insert(MangaEntry(id: id1, name: "A"))
        context.insert(MangaEntry(id: id2, name: "B"))
        try context.save()

        let vm = MangaViewModel(modelContext: context)
        let result = vm.findEntries(by: [id1, id2])

        #expect(result.count == 2)
        #expect(result[id1]?.name == "A")
        #expect(result[id2]?.name == "B")
    }
}

@Suite("MangaViewModel.runStartupMigrationsIfNeeded")
struct MangaViewModelStartupTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: MangaEntry.self, ReadingActivity.self, MangaComment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("legacy entry が 1 回だけ migration される (2 回目は no-op)")
    @MainActor
    func runsMigrationOnceAcrossCalls() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 旧 isCompleted=true の legacy entry を入れておく
        let legacy = MangaEntry(name: "old")
        legacy.stateMigrationVersion = 0
        legacy.isCompleted = true
        context.insert(legacy)
        try context.save()

        let vm = MangaViewModel(modelContext: context)

        // 1 回目: migration が走って archived になる
        vm.runStartupMigrationsIfNeeded()
        #expect(legacy.readingState == .archived)
        #expect(legacy.stateMigrationVersion == 1)

        // 2 回目以降を呼んでも既に migration 済みなので状態変化なし
        legacy.readingState = .following // 仮に何らかの理由で変わったとして
        vm.runStartupMigrationsIfNeeded()
        #expect(legacy.readingState == .following) // migration が再走しないので戻されない
    }
}
