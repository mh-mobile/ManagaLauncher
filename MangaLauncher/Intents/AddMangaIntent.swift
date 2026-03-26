import AppIntents
import SwiftData

enum DayOfWeekAppEnum: String, AppEnum {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "曜日"
    }

    static var caseDisplayRepresentations: [DayOfWeekAppEnum: DisplayRepresentation] {
        [
            .sunday: "日曜日",
            .monday: "月曜日",
            .tuesday: "火曜日",
            .wednesday: "水曜日",
            .thursday: "木曜日",
            .friday: "金曜日",
            .saturday: "土曜日",
        ]
    }

    var toDayOfWeek: DayOfWeek {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}

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

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        let intentData: [String: String] = [
            "name": name,
            "url": url,
            "dayOfWeek": String(dayOfWeek.toDayOfWeek.rawValue),
            "publisher": publisher ?? "",
            "iconColor": (iconColor ?? .blue).rawValue,
        ]
        defaults?.set(intentData, forKey: "pendingIntentData")

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

// MARK: - Open Day Intent

struct OpenDayIntent: AppIntent {
    static var title: LocalizedStringResource = "曜日を開く"
    static var description: IntentDescription = "マンガ曜日で指定した曜日のタブを開きます"
    static var openAppWhenRun = true

    @Parameter(title: "曜日")
    var dayOfWeek: DayOfWeekAppEnum

    func perform() async throws -> some IntentResult {
        let rawValue = dayOfWeek.toDayOfWeek.rawValue
        // For when app needs to launch
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        defaults?.set(rawValue, forKey: "pendingOpenDay")
        // For when app is already running
        await MainActor.run {
            NotificationCenter.default.post(name: .switchToDay, object: rawValue)
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
