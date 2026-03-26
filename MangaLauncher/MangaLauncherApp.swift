import SwiftUI
import SwiftData

import UserNotifications

extension Notification.Name {
    static let mangaDataDidChange = Notification.Name("mangaDataDidChange")
    static let switchToDay = Notification.Name("switchToDay")
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        // identifier format: "manga_reminder_X" where X is DayOfWeek.rawValue
        if identifier.hasPrefix("manga_reminder_"),
           let rawString = identifier.split(separator: "_").last,
           let rawValue = Int(rawString),
           let day = DayOfWeek(rawValue: rawValue) {
            NotificationCenter.default.post(name: .switchToDay, object: day.rawValue)
        }
        completionHandler()
    }
}

struct IntentPrefill: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let dayOfWeek: DayOfWeek
    let publisher: String
    let iconColor: String
    let imageData: Data?
}

@main
struct MangaLauncherApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var intentPrefill: IntentPrefill?
    @State private var syncMonitor = CloudSyncMonitor()
    private let notificationDelegate = NotificationDelegate()

    init() {
        DataMigration.migrateToAppGroupIfNeeded()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        do {
            container = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncMonitor)
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
                        prefilledColor: prefill.iconColor,
                        prefilledImageData: prefill.imageData
                    )
                }
                .onAppear {
                    checkPendingIntent()
                    checkPendingOpenDay()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        checkPendingIntent()
                        checkPendingOpenDay()
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

        // Load image from temp file if exists
        var imageData: Data?
        if let containerURL = SharedModelContainer.appGroupContainerURL {
            let imageURL = containerURL.appendingPathComponent("pendingIntentImage.jpg")
            imageData = try? Data(contentsOf: imageURL)
            try? FileManager.default.removeItem(at: imageURL)
        }

        let dayRaw = Int(data["dayOfWeek"] ?? "") ?? DayOfWeek.today.rawValue
        intentPrefill = IntentPrefill(
            name: data["name"] ?? "",
            url: data["url"] ?? "",
            dayOfWeek: DayOfWeek(rawValue: dayRaw) ?? .today,
            publisher: data["publisher"] ?? "",
            iconColor: data["iconColor"] ?? "blue",
            imageData: imageData
        )
    }

    private func checkPendingOpenDay() {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        guard let rawValue = defaults?.object(forKey: "pendingOpenDay") as? Int else { return }
        defaults?.removeObject(forKey: "pendingOpenDay")
        NotificationCenter.default.post(name: .switchToDay, object: rawValue)
    }

    private func updateBadge() {
        let viewModel = MangaViewModel(modelContext: container.mainContext)
        let count = viewModel.unreadCount(for: .today)
        BadgeManager.updateBadge(unreadCount: count)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mangalauncher",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        if url.host == "day",
           let weekdayString = components.queryItems?.first(where: { $0.name == "weekday" })?.value,
           let rawValue = Int(weekdayString) {
            NotificationCenter.default.post(name: .switchToDay, object: rawValue)
            return
        }

        if url.host == "open",
           let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
           let entryID = UUID(uuidString: idString) {
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
}
