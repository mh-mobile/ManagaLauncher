import SwiftUI
import SwiftData

extension Notification.Name {
    static let mangaDataDidChange = Notification.Name("mangaDataDidChange")
}

struct IntentPrefill: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let dayOfWeek: DayOfWeek
    let publisher: String
    let iconColor: String
}

@main
struct MangaLauncherApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var intentPrefill: IntentPrefill?

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
                .sheet(item: $intentPrefill, onDismiss: {
                    // Force refresh ContentView after intent registration
                    NotificationCenter.default.post(name: .mangaDataDidChange, object: nil)
                }) { prefill in
                    EditEntryView(
                        viewModel: MangaViewModel(modelContext: container.mainContext),
                        prefilledName: prefill.name,
                        prefilledURL: prefill.url,
                        prefilledDay: prefill.dayOfWeek,
                        prefilledPublisher: prefill.publisher,
                        prefilledColor: prefill.iconColor
                    )
                }
                .onAppear {
                    checkPendingIntent()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        checkPendingIntent()
                        NotificationCenter.default.post(name: .mangaDataDidChange, object: nil)
                        updateBadge()
                    }
                }
        }
        .modelContainer(container)
    }

    private func checkPendingIntent() {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        guard let data = defaults?.dictionary(forKey: "pendingIntentData") as? [String: String] else { return }
        defaults?.removeObject(forKey: "pendingIntentData")

        let dayRaw = Int(data["dayOfWeek"] ?? "") ?? DayOfWeek.today.rawValue
        intentPrefill = IntentPrefill(
            name: data["name"] ?? "",
            url: data["url"] ?? "",
            dayOfWeek: DayOfWeek(rawValue: dayRaw) ?? .today,
            publisher: data["publisher"] ?? "",
            iconColor: data["iconColor"] ?? "blue"
        )
    }

    private func updateBadge() {
        let viewModel = MangaViewModel(modelContext: container.mainContext)
        let count = viewModel.unreadCount(for: .today)
        BadgeManager.updateBadge(unreadCount: count)
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
