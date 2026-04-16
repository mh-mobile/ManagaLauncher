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

    static func create() throws -> ModelContainer {
        let schema = Schema([MangaEntry.self, ReadingActivity.self, MangaComment.self])
        let config = ModelConfiguration(
            "MangaLauncher",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// CloudKit 設定が原因で create() が失敗した場合のフォールバック。
    /// CloudKit を切ってローカル only で起動を試みる。
    /// 同期は止まるが、最低限アプリが立ち上がりデータ閲覧/編集ができる状態を保つ。
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
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
}
