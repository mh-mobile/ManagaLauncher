import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct MangaTimelineEntry: TimelineEntry {
    let date: Date
    let items: [MangaWidgetItem]
    let dayOfWeek: DayOfWeek
}

struct MangaWidgetItem: Identifiable {
    let id: UUID
    let name: String
    let url: String
    let iconColor: String
    let publisher: String
}

// MARK: - Timeline Provider

struct MangaTimelineProvider: TimelineProvider {
    let container: ModelContainer

    func placeholder(in context: Context) -> MangaTimelineEntry {
        MangaTimelineEntry(date: .now, items: [], dayOfWeek: .today)
    }

    func getSnapshot(in context: Context, completion: @escaping (MangaTimelineEntry) -> Void) {
        completion(fetchEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MangaTimelineEntry>) -> Void) {
        let entry = fetchEntry(for: .now)
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func fetchEntry(for date: Date) -> MangaTimelineEntry {
        let today = DayOfWeek.today
        let dayRaw = today.rawValue
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.dayOfWeekRawValue == dayRaw },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let results = (try? context.fetch(descriptor)) ?? []
        let items = results.map {
            MangaWidgetItem(id: $0.id, name: $0.name, url: $0.url, iconColor: $0.iconColor, publisher: $0.publisher)
        }
        return MangaTimelineEntry(date: date, items: items, dayOfWeek: today)
    }
}

// MARK: - Widget Views

struct MangaWidgetEntryView: View {
    var entry: MangaTimelineEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        #if os(iOS)
        case .accessoryRectangular:
            lockScreenView
        #endif
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.dayOfWeek.shortName)
                    .font(.headline.bold())
                Text("のマンガ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if entry.items.isEmpty {
                Spacer()
                Text("登録なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    Link(destination: deepLink(for: item.id)) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorFromName(item.iconColor))
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(entry.dayOfWeek.displayName)のマンガ")
                    .font(.headline)
                Spacer()
                Text("\(entry.items.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.items.isEmpty {
                Spacer()
                Text("登録なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items.prefix(5)) { item in
                    Link(destination: deepLink(for: item.id)) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorFromName(item.iconColor))
                                .frame(width: 10, height: 10)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                            if !item.publisher.isEmpty {
                                Spacer()
                                Text(item.publisher)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    #if os(iOS)
    private var lockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.dayOfWeek.shortName)曜のマンガ")
                .font(.headline)
                .widgetAccentable()
            ForEach(entry.items.prefix(2)) { item in
                Text(item.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            if entry.items.isEmpty {
                Text("登録なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif

    private func deepLink(for id: UUID) -> URL {
        URL(string: "mangalauncher://open?id=\(id.uuidString)")!
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        default: .blue
        }
    }
}

// MARK: - Widget Declaration

@main
struct MangaLauncherWidget: Widget {
    let kind = "MangaWidget"

    private var container: ModelContainer {
        try! SharedModelContainer.create()
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MangaTimelineProvider(container: container)) { entry in
            MangaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日のマンガ")
        .description("今日更新のマンガを表示します")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium]
        #if os(iOS)
        families.append(.accessoryRectangular)
        #endif
        return families
    }
}
