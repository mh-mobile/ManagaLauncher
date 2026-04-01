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
        let schema = Schema([MangaEntry.self, ReadingActivity.self])
        let config = ModelConfiguration(
            "MangaLauncher",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
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
