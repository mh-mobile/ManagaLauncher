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
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(container)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mangalauncher",
              url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let entryID = UUID(uuidString: idString) else { return }

        let context = container.mainContext
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        guard let entry = try? context.fetch(descriptor).first,
              let targetURL = URL(string: entry.url) else { return }

        #if canImport(UIKit)
        UIApplication.shared.open(targetURL)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(targetURL)
        #endif
    }
}
