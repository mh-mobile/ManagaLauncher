import WidgetKit
import SwiftUI
import SwiftData
import PlatformKit

// MARK: - Timeline Entry

struct MangaTimelineEntry: TimelineEntry {
    let date: Date
    let items: [MangaWidgetItem]
    let dayOfWeek: DayOfWeek
    let isToday: Bool
}

struct MangaWidgetItem: Identifiable {
    let id: UUID
    let name: String
    let url: String
    let iconColor: String
    let publisher: String
    let imageData: Data?
    let isRead: Bool
}

// MARK: - Timeline Provider

struct MangaTimelineProvider: TimelineProvider {
    let container: ModelContainer

    func placeholder(in context: Context) -> MangaTimelineEntry {
        MangaTimelineEntry(date: .now, items: [], dayOfWeek: .today, isToday: true)
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
        let selectedDay = WidgetDayStore.shared.currentDay
        let dayRaw = selectedDay.rawValue
        let context = ModelContext(container)
        // 連載中 × 追っかけ中のエントリのみ表示
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate {
                $0.dayOfWeekRawValue == dayRaw
                    && $0.publicationStatusRawValue == 0
                    && $0.readingStateRawValue == 0
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let results = (try? context.fetch(descriptor)) ?? []
        let items = results.map {
            MangaWidgetItem(
                id: $0.id, name: $0.name, url: $0.url,
                iconColor: $0.iconColor, publisher: $0.publisher,
                imageData: $0.imageData,
                isRead: $0.isRead
            )
        }
        return MangaTimelineEntry(
            date: date, items: items, dayOfWeek: selectedDay,
            isToday: selectedDay == DayOfWeek.today
        )
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
        case .systemLarge:
            largeView
        #if os(iOS)
        case .accessoryRectangular:
            lockScreenView
        #endif
        default:
            smallView
        }
    }

    // MARK: - Header with day navigation

    private func header(compact: Bool = false) -> some View {
        HStack(spacing: 0) {
            Button(intent: ChangeDayIntent(direction: -1)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if entry.isToday {
                Text(compact ? "\(entry.dayOfWeek.shortName)曜" : "\(entry.dayOfWeek.displayName)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            } else {
                Button(intent: ChangeDayIntent(direction: 0)) {
                    HStack(spacing: 2) {
                        Text(compact ? "\(entry.dayOfWeek.shortName)曜" : "\(entry.dayOfWeek.displayName)")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Button(intent: ChangeDayIntent(direction: 1)) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(entry.items.count)件")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Small Widget (2x2)

    private var smallView: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 16
            let spacing: CGFloat = 4
            let cols = 2
            let rows = 2
            let gridWidth = geo.size.width
            let gridHeight = geo.size.height - headerHeight - spacing
            let cellW = (gridWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (gridHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let cellSize = min(cellW, cellH)

            VStack(spacing: spacing) {
                header(compact: true)
                    .frame(height: headerHeight)

                if entry.items.isEmpty {
                    Spacer()
                    Text("登録なし")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    let items = Array(entry.items.prefix(4))
                    Spacer(minLength: 0)
                    VStack(spacing: spacing) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let idx = row * cols + col
                                    if idx < items.count {
                                        gridCell(item: items[idx], size: cellSize)
                                    } else {
                                        Color.clear.frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Medium Widget (4x2)

    private var mediumView: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 16
            let spacing: CGFloat = 4
            let cols = 4
            let rows = 2
            let gridWidth = geo.size.width
            let gridHeight = geo.size.height - headerHeight - spacing
            let cellW = (gridWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (gridHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let cellSize = min(cellW, cellH)

            VStack(spacing: spacing) {
                header()
                    .frame(height: headerHeight)

                if entry.items.isEmpty {
                    Spacer()
                    Text("登録なし")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    let items = Array(entry.items.prefix(8))
                    Spacer(minLength: 0)
                    VStack(spacing: spacing) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let idx = row * cols + col
                                    if idx < items.count {
                                        gridCell(item: items[idx], size: cellSize)
                                    } else {
                                        Color.clear.frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Large Widget (4x4)

    private var largeView: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 16
            let spacing: CGFloat = 4
            let cols = 4
            let rows = 4
            let gridWidth = geo.size.width
            let gridHeight = geo.size.height - headerHeight - spacing
            let cellW = (gridWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (gridHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let cellSize = min(cellW, cellH)

            VStack(spacing: spacing) {
                header()
                    .frame(height: headerHeight)

                if entry.items.isEmpty {
                    Spacer()
                    Text("登録なし")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    let items = Array(entry.items.prefix(16))
                    Spacer(minLength: 0)
                    VStack(spacing: spacing) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let idx = row * cols + col
                                    if idx < items.count {
                                        gridCell(item: items[idx], size: cellSize)
                                    } else {
                                        Color.clear.frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Lock Screen

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
        .containerBackground(.clear, for: .widget)
    }
    #endif

    // MARK: - Grid Cell

    private func gridCell(item: MangaWidgetItem, size: CGFloat) -> some View {
        Link(destination: URL(string: "mangalauncher://open?id=\(item.id.uuidString)")!) {
            Group {
                if let imageData = item.imageData, let image = imageData.toSwiftUIImage() {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Rectangle()
                        .fill(Color.fromName(item.iconColor))
                        .overlay {
                            Text(item.name)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(2)
                        }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .topLeading) {
                if !item.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(3)
                }
            }
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
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        #if os(iOS)
        families.append(.accessoryRectangular)
        #endif
        return families
    }
}
