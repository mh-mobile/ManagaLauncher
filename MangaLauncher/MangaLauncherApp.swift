import SwiftUI
import SwiftData
import UserNotifications
import NotificationKit
import CloudSyncKit

/// sheet/fullScreenCover内で `.preferredColorScheme(nil)` が親を継承する問題の回避用。
/// UIKitからOS設定のカラースキームを直接取得する。
var systemColorScheme: ColorScheme {
    let style = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
        .traitCollection.userInterfaceStyle
    return style == .dark ? .dark : .light
}

extension Notification.Name {
    static let mangaDataDidChange = CloudSyncMonitor.dataDidChangeNotification
    // .switchToDay / .openCatchUp は ControlIntents.swift (widget extension とも共有) で定義
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
    let isOneShot: Bool
}

@main
struct MangaLauncherApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var intentPrefill: IntentPrefill?
    @State private var syncMonitor = CloudSyncMonitor()
    /// アプリ全体で共有する単一の MangaViewModel。
    /// 各タブが独自インスタンスを持つと ModelContext が分散して
    /// CloudKit sync 時に複数 refresh が走るので、ここで 1 つだけ作る。
    @State private var viewModel: MangaViewModel
    private let notificationDelegate = NotificationDelegate()

    init() {
        DataMigration.migrateToAppGroupIfNeeded()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        let container: ModelContainer
        do {
            container = try SharedModelContainer.create()
        } catch {
            // CloudKit 設定不整合などで初期化に失敗するケースを fatalError で
            // 落とすと TestFlight でクラッシュ報告に直結する。ローカル only に
            // 切り替えてアプリは起動させ、syncMonitor 側で sync 不可状態を
            // 表示することで graceful degradation する。
            print("[MangaLauncherApp] CloudKit container failed: \(error). Falling back to local-only.")
            do {
                container = try SharedModelContainer.createLocalOnly()
            } catch {
                fatalError("Failed to create ModelContainer (even local-only): \(error)")
            }
        }
        self.container = container
        self._viewModel = State(initialValue: MangaViewModel(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(viewModel: viewModel)
                .background {
                    // Ink background applied OUTSIDE ContentView to avoid breaking drag
                    ThemeManager.shared.style.groupedBackground.ignoresSafeArea()
                }
                .preferredColorScheme(ThemeManager.shared.style.colorSchemeOverride)
                .environment(syncMonitor)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .sheet(item: $intentPrefill, onDismiss: {
                    // Force refresh ContentView after intent registration
                    NotificationCenter.default.post(name: .mangaDataDidChange, object: nil)
                }) { prefill in
                    EditEntryView(
                        viewModel: viewModel,
                        prefilledName: prefill.name,
                        prefilledURL: prefill.url,
                        prefilledDay: prefill.dayOfWeek,
                        prefilledPublisher: prefill.publisher,
                        prefilledColor: prefill.iconColor,
                        prefilledImageData: prefill.imageData,
                        prefilledIsOneShot: prefill.isOneShot
                    )
                }
                .onAppear {
                    // CloudKit 同期がある程度落ち着いてから migration を走らせる
                    // (init で同期前に走らせるとローカルのデフォルト値で上書きされるリスクあり)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        viewModel.runStartupMigrationsIfNeeded()
                    }
                    checkPendingIntent()
                    checkPendingOpenDay()
                    checkPendingOpenCatchUp()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        viewModel.runStartupMigrationsIfNeeded()
                        checkPendingIntent()
                        checkPendingOpenDay()
                        checkPendingOpenCatchUp()
                        NotificationCenter.default.post(name: .mangaDataDidChange, object: nil)
                        updateBadge()
                    }
                }
        }
        .modelContainer(container)
    }

    private func checkPendingIntent() {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        guard let data = defaults?.dictionary(forKey: UserDefaultsKeys.pendingIntentData) as? [String: String] else { return }
        defaults?.removeObject(forKey: UserDefaultsKeys.pendingIntentData)

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
            imageData: imageData,
            isOneShot: data["isOneShot"] == "true"
        )
    }

    private func checkPendingOpenDay() {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        guard let rawValue = defaults?.object(forKey: UserDefaultsKeys.pendingOpenDay) as? Int else { return }
        defaults?.removeObject(forKey: UserDefaultsKeys.pendingOpenDay)
        NotificationCenter.default.post(name: .switchToDay, object: rawValue)
    }

    private func checkPendingOpenCatchUp() {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        guard defaults?.bool(forKey: UserDefaultsKeys.pendingOpenCatchUp) == true else { return }
        defaults?.removeObject(forKey: UserDefaultsKeys.pendingOpenCatchUp)
        NotificationCenter.default.post(name: .openCatchUp, object: nil)
    }

    private func updateBadge() {
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
