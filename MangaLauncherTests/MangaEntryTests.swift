//
//  MangaEntryTests.swift
//  MangaLauncherTests
//
//  2 軸状態モデル (PublicationStatus × ReadingState) と invariant のテスト。
//

import Testing
import Foundation
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
}
