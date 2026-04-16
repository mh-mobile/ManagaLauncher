import AppIntents
import SwiftUI
import WidgetKit

/// コントロールセンター: 「マンガを登録」ボタン
struct MangaAddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "MangaAddControl") {
            ControlWidgetButton(action: OpenAddEntryIntent()) {
                Label("マンガを登録", systemImage: "plus.circle.fill")
            }
        }
        .displayName("マンガを登録")
        .description("新しいマンガをすばやく登録")
    }
}

/// コントロールセンター: 「今日のマンガを開く」ボタン
struct MangaTodayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "MangaTodayControl") {
            ControlWidgetButton(action: OpenTodayIntent()) {
                Label("今日のマンガ", systemImage: "calendar")
            }
        }
        .displayName("今日のマンガを開く")
        .description("マンガ曜日で今日のタブを開く")
    }
}

/// コントロールセンター: 「今日のキャッチアップを開始」ボタン
struct MangaCatchUpControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "MangaCatchUpControl") {
            ControlWidgetButton(action: OpenCatchUpIntent()) {
                Label("今日のキャッチアップ", systemImage: "rectangle.stack.fill")
            }
        }
        .displayName("今日のキャッチアップを開始")
        .description("今日の未読マンガをスワイプでさばく")
    }
}

/// コントロールセンター: 「曜日を選んでタブを開く」設定式ボタン。
/// コントロール追加時に曜日を選び、タップでその曜日のタブを開く。
struct MangaDayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "MangaDayControl",
            intent: DayConfigurationIntent.self
        ) { configuration in
            let day = configuration.dayOfWeek ?? .monday
            ControlWidgetButton(action: openDayIntent(for: day)) {
                Label(day.label, systemImage: day.iconName)
            }
        }
        .displayName("曜日のタブを開く")
        .description("選んだ曜日のタブを開く")
    }

    private func openDayIntent(for day: DayOfWeekAppEnum) -> OpenDayIntent {
        var intent = OpenDayIntent()
        intent.dayOfWeek = day
        return intent
    }
}

private extension DayOfWeekAppEnum {
    var label: String {
        switch self {
        case .sunday: "日曜日"
        case .monday: "月曜日"
        case .tuesday: "火曜日"
        case .wednesday: "水曜日"
        case .thursday: "木曜日"
        case .friday: "金曜日"
        case .saturday: "土曜日"
        }
    }

    /// 曜日の漢字の由来 (陰陽五行 + 太陽 + 月) に対応した SF Symbol。
    /// 日=太陽, 月=月, 火=炎, 水=水滴, 木=木, 金=金属(レンチ), 土=大地(山)
    var iconName: String {
        switch self {
        case .sunday: "sun.max.fill"
        case .monday: "moon.fill"
        case .tuesday: "flame.fill"
        case .wednesday: "drop.fill"
        case .thursday: "tree.fill"
        case .friday: "wrench.fill"
        case .saturday: "mountain.2.fill"
        }
    }
}
