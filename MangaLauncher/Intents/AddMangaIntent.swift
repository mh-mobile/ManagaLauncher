import AppIntents
import SwiftData
import PlatformKit

enum IconColorAppEnum: String, AppEnum {
    case red, orange, yellow, green, blue, purple, pink, teal

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "アイコンカラー"
    }

    static var caseDisplayRepresentations: [IconColorAppEnum: DisplayRepresentation] {
        [
            .red: "赤",
            .orange: "オレンジ",
            .yellow: "黄",
            .green: "緑",
            .blue: "青",
            .purple: "紫",
            .pink: "ピンク",
            .teal: "ティール",
        ]
    }
}

// MARK: - Full registration intent (from Shortcuts app)

struct AddMangaIntent: AppIntent {
    static var title: LocalizedStringResource = "マンガを登録"
    static var description: IntentDescription = "マンガ曜日に新しいマンガを登録します"
    static var openAppWhenRun = true

    @Parameter(title: "名前")
    var name: String

    @Parameter(title: "URL")
    var url: String

    @Parameter(title: "曜日")
    var dayOfWeek: DayOfWeekAppEnum

    @Parameter(title: "掲載誌", default: "")
    var publisher: String?

    @Parameter(title: "アイコンカラー", default: .blue)
    var iconColor: IconColorAppEnum?

    @Parameter(title: "画像", supportedContentTypes: [.image])
    var image: IntentFile?

    @Parameter(title: "読み切り", default: false)
    var isOneShot: Bool

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        let intentData: [String: String] = [
            "name": name,
            "url": url,
            "dayOfWeek": String(dayOfWeek.toDayOfWeek.rawValue),
            "publisher": publisher ?? "",
            "iconColor": (iconColor ?? .blue).rawValue,
            "isOneShot": isOneShot ? "true" : "false",
        ]
        defaults?.set(intentData, forKey: UserDefaultsKeys.pendingIntentData)

        // Save image to App Group temp file
        if let image,
           let containerURL = SharedModelContainer.appGroupContainerURL {
            let imageURL = containerURL.appendingPathComponent("pendingIntentImage.jpg")
            if let jpeg = downsizedJPEGData(image.data, maxDimension: 600) {
                try? jpeg.write(to: imageURL)
            }
        }

        return .result()
    }
}

// MARK: - App Shortcuts

struct MangaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddMangaIntent(),
            phrases: [
                "マンガを\(.applicationName)に登録",
                "\(.applicationName)にマンガを追加",
            ],
            shortTitle: "マンガを登録",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenDayIntent(),
            phrases: [
                "\(.applicationName)で\(\.$dayOfWeek)を開く",
                "\(.applicationName)で\(\.$dayOfWeek)を開いて",
                "\(.applicationName)で\(\.$dayOfWeek)を見せて",
                "\(.applicationName)の\(\.$dayOfWeek)",
                "\(.applicationName)の\(\.$dayOfWeek)を開いて",
            ],
            shortTitle: "曜日を開く",
            systemImageName: "calendar"
        )
    }
}
