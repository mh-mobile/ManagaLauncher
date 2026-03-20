import SwiftUI
import SwiftData

@main
struct MangaLauncherApp: App {
    let container: ModelContainer
    @State private var pendingShareData: PendingShareData?

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
                .sheet(item: $pendingShareData) { pending in
                    EditEntryView(
                        viewModel: MangaViewModel(modelContext: container.mainContext),
                        prefilled: pending
                    )
                }
        }
        .modelContainer(container)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mangalauncher",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        switch url.host {
        case "open":
            guard let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
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

        case "add":
            guard let pendingID = components.queryItems?.first(where: { $0.name == "pending" })?.value,
                  let uuid = UUID(uuidString: pendingID),
                  let pending = PendingShareData.load(id: uuid) else { return }
            PendingShareData.delete(id: uuid)
            pendingShareData = pending

        default:
            break
        }
    }
}
