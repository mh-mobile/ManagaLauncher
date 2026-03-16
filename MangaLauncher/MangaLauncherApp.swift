import SwiftUI
import SwiftData

@main
struct MangaLauncherApp: App {
    let container: ModelContainer

    init() {
        DataMigration.migrateToAppGroupIfNeeded()
        do {
            container = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
