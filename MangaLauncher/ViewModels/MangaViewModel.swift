import Foundation
import Observation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

@Observable
final class MangaViewModel {
    var selectedDay: DayOfWeek = .today
    private(set) var refreshCounter = 0

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchEntries(for day: DayOfWeek) -> [MangaEntry] {
        let dayRawValue = day.rawValue
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.dayOfWeekRawValue == dayRawValue },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addEntry(name: String, url: String, days: Set<DayOfWeek>, iconColor: String, publisher: String = "", imageData: Data? = nil) {
        for day in days {
            let existingEntries = fetchEntries(for: day)
            let maxOrder = existingEntries.map(\.sortOrder).max() ?? -1
            let entry = MangaEntry(
                name: name,
                url: url,
                dayOfWeek: day,
                sortOrder: maxOrder + 1,
                iconColor: iconColor,
                publisher: publisher,
                imageData: imageData
            )
            modelContext.insert(entry)
        }
        save()
    }

    func updateEntry(_ entry: MangaEntry, name: String, url: String, dayOfWeek: DayOfWeek, iconColor: String, publisher: String = "", imageData: Data? = nil) {
        entry.name = name
        entry.url = url
        entry.dayOfWeek = dayOfWeek
        entry.iconColor = iconColor
        entry.publisher = publisher
        entry.imageData = imageData
        save()
    }

    func publishers(for day: DayOfWeek) -> [String] {
        let entries = fetchEntries(for: day)
        let publishers = Set(entries.map(\.publisher)).filter { !$0.isEmpty }
        return publishers.sorted()
    }

    func allPublishers() -> [String] {
        let descriptor = FetchDescriptor<MangaEntry>()
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        let publishers = Set(entries.map(\.publisher)).filter { !$0.isEmpty }
        return publishers.sorted()
    }

    func deleteEntry(_ entry: MangaEntry) {
        modelContext.delete(entry)
        save()
    }

    func moveEntries(for day: DayOfWeek, from source: IndexSet, to destination: Int) {
        var entries = fetchEntries(for: day)
        entries.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in entries.enumerated() {
            entry.sortOrder = index
        }
        save()
    }

    func findEntry(by id: UUID) -> MangaEntry? {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func save() {
        try? modelContext.save()
        refreshCounter += 1
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
