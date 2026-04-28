import Foundation
import SwiftData

enum SharedModelContainer {
    #if DEBUG
    static let appGroupIdentifier = "group.com.mh-mobile.MangaYoubi.dev"
    #elseif ADHOC
    static let appGroupIdentifier = "group.com.mh-mobile.MangaYoubi.adhoc"
    #else
    static let appGroupIdentifier = "group.com.mh-mobile.MangaYoubi"
    #endif

    /// CloudKit 付きの ModelContainer を最大 `maxAttempts` 回リトライして生成する。
    /// アプリ更新直後など CloudKit の準備が間に合わない一時的な失敗を吸収する。
    /// 全試行失敗時は最後のエラーを throw する。
    static func create(maxAttempts: Int = 3) throws -> ModelContainer {
        let schema = Schema([MangaEntry.self, ReadingActivity.self, MangaComment.self])
        let config = ModelConfiguration(
            "MangaLauncher",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
        )
        let attempts = max(1, maxAttempts)
        var lastError: Error?
        for attempt in 1...attempts {
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                lastError = error
                print("[SharedModelContainer] create() attempt \(attempt)/\(attempts) failed: \(error)")
                if attempt < attempts {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
        guard let error = lastError else {
            fatalError("[SharedModelContainer] create() ended without error or container – should be unreachable")
        }
        throw error
    }

    /// CloudKit 付きコンテナの生成が全リトライで失敗した場合の最終フォールバック。
    /// CloudKit を切ってローカル only で起動を試みる。
    /// 同期は止まるが、最低限アプリが立ち上がりデータ閲覧/編集ができる状態を保つ。
    ///
    /// 注: store URL は通常版と同じ (App Group 内 MangaLauncher.store) なので
    /// データ連続性は保たれる。次回起動で CloudKit が回復していれば create() に
    /// 戻り、ローカル更新分も sync される (SwiftData が変更を検出して push)。
    static func createLocalOnly() throws -> ModelContainer {
        let schema = Schema([MangaEntry.self, ReadingActivity.self, MangaComment.self])
        let config = ModelConfiguration(
            "MangaLauncher",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    static var storeURL: URL {
        let directory = appGroupContainerURL ?? fallbackURL
        return directory.appendingPathComponent("MangaLauncher.store")
    }

    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static var fallbackURL: URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory not found")
        }
        return url
    }
}
