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
    /// CloudKit 接続失敗時に local-only にフォールバックしたことを示すフラグ。
    /// アラートは表示せず、同期状態は設定画面の iCloud 同期セクションで確認できる。
    /// startup migration の待機 Task が既に起動しているか。
    /// onAppear と scenePhase=.active が近接して発火した場合に Task を 2 つ
    /// 立ち上げないためのガード。後発 Task が「sync 開始前に return」して
    /// 古いローカルデータで migration を走らせるリスクを排除する。
    @State private var migrationWaitStarted = false
    private let notificationDelegate = NotificationDelegate()

    init() {
        DataMigration.migrateToAppGroupIfNeeded()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        let container: ModelContainer
        do {
            // 最大3回リトライしてCloudKit付きコンテナの生成を試みる。
            // アプリ更新直後など一時的な失敗で同期が止まるのを防ぐ。
            container = try SharedModelContainer.create()
        } catch {
            // 全リトライ失敗時のみ local-only にフォールバック。
            // 同期状態は設定画面の「iCloud同期」セクションで確認可能。
            print("[MangaLauncherApp] CloudKit container failed after retries: \(error). Falling back to local-only.")
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
                    startMigrationWaitIfNeeded()
                    checkPendingIntent()
                    checkPendingOpenDay()
                    checkPendingOpenCatchUp()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        startMigrationWaitIfNeeded()
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

    /// startup migration の Task を 1 つだけ起動するエントリポイント。
    /// 既に起動済みなら no-op。Task 内で sync 完了待ち + migration を実行。
    private func startMigrationWaitIfNeeded() {
        guard !migrationWaitStarted else { return }
        migrationWaitStarted = true
        Task { @MainActor in
            await waitForCloudSyncSettle()
            viewModel.runStartupMigrationsIfNeeded()
        }
    }

    /// CloudKit sync が落ち着くのを待ってから return。
    /// - 初期 .idle で 3 秒待っても sync が始まらなければそのまま return (cold start で
    ///   syncing event が来ないケース、初回データ無しのケース)。3 秒は CloudKit が
    ///   wake up するのに必要な余裕を見たもの
    /// - .syncing になったら .idle / .failed / .notAvailable に変わるまで待つ
    /// - 最大タイムアウト 10 秒
    @MainActor
    private func waitForCloudSyncSettle() async {
        let timeout: TimeInterval = 10
        let initialIdleGrace: TimeInterval = 3
        let pollNanoseconds: UInt64 = 200_000_000 // 0.2s
        let start = Date()
        var sawSyncing = false

        while Date().timeIntervalSince(start) < timeout {
            switch syncMonitor.syncStatus {
            case .syncing:
                sawSyncing = true
            case .failed, .notAvailable:
                return
            case .idle:
                if sawSyncing { return }
                if Date().timeIntervalSince(start) > initialIdleGrace { return }
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
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
