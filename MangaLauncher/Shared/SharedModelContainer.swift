import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.example.MangaLauncher"

    static func create() throws -> ModelContainer {
        let schema = Schema([MangaEntry.self])
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
