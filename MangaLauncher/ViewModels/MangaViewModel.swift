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
    var pendingDeleteEntries: [MangaEntry] = []
    private var deleteTimer: Timer?

    private(set) var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchEntries(for day: DayOfWeek) -> [MangaEntry] {
        let _ = refreshCounter
        let dayRawValue = day.rawValue
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.dayOfWeekRawValue == dayRawValue },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        // Deduplicate by ID (CloudKit sync can cause temporary duplicates)
        var seenIDs = Set<UUID>()
        return results.filter { entry in
            guard !pendingIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }
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

    func queueDelete(_ entry: MangaEntry) {
        pendingDeleteEntries.append(entry)
        refreshCounter += 1
        restartDeleteTimer()
    }

    func undoPendingDeletes() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        pendingDeleteEntries.removeAll()
        refreshCounter += 1
    }

    func commitPendingDeletes() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        for entry in pendingDeleteEntries {
            modelContext.delete(entry)
        }
        pendingDeleteEntries.removeAll()
        save()
    }

    private func restartDeleteTimer() {
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitPendingDeletes()
            }
        }
    }

    func moveEntries(for day: DayOfWeek, from source: IndexSet, to destination: Int) {
        var entries = fetchEntries(for: day)
        entries.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in entries.enumerated() {
            entry.sortOrder = index
        }
        save()
    }

    func deleteAllEntries() {
        let descriptor = FetchDescriptor<MangaEntry>()
        guard let entries = try? modelContext.fetch(descriptor) else { return }
        for entry in entries {
            modelContext.delete(entry)
        }
        save()
    }

    func totalEntryCount() -> Int {
        let descriptor = FetchDescriptor<MangaEntry>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func exportBackupData() -> Data? {
        let descriptor = FetchDescriptor<MangaEntry>(sortBy: [SortDescriptor(\.dayOfWeekRawValue), SortDescriptor(\.sortOrder)])
        guard let entries = try? modelContext.fetch(descriptor) else { return nil }
        let backup = BackupData.from(entries)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    func importBackupData(_ data: Data) -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupData.self, from: data) else { return 0 }

        let existingIDs = Set((try? modelContext.fetch(FetchDescriptor<MangaEntry>()))?.map(\.id) ?? [])

        var importedCount = 0
        for backupEntry in backup.entries {
            guard !existingIDs.contains(backupEntry.id) else { continue }
            let entry = MangaEntry(
                id: backupEntry.id,
                name: backupEntry.name,
                url: backupEntry.url,
                dayOfWeek: DayOfWeek(rawValue: backupEntry.dayOfWeekRawValue) ?? .monday,
                sortOrder: backupEntry.sortOrder,
                iconColor: backupEntry.iconColor,
                publisher: backupEntry.publisher,
                imageData: backupEntry.imageData
            )
            entry.lastReadDate = backupEntry.lastReadDate
            modelContext.insert(entry)
            importedCount += 1
        }
        if importedCount > 0 { save() }
        return importedCount
    }

    func findEntry(by id: UUID) -> MangaEntry? {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func markAsRead(_ entry: MangaEntry) {
        entry.lastReadDate = Date()
        save()
    }

    func markAsUnread(_ entry: MangaEntry) {
        entry.lastReadDate = nil
        save()
    }

    func unreadEntries(for day: DayOfWeek) -> [MangaEntry] {
        fetchEntries(for: day).filter { !$0.isRead }
    }

    func unreadCount(for day: DayOfWeek) -> Int {
        unreadEntries(for: day).count
    }

    func rescheduleNotifications() {
        var counts: [DayOfWeek: Int] = [:]
        for day in DayOfWeek.allCases {
            counts[day] = fetchEntries(for: day).count
        }
        NotificationManager.scheduleNotifications(entryCounts: counts)
    }

    func notifyChange() {
        refreshCounter += 1
    }

    func refresh() {
        modelContext = ModelContext(modelContext.container)
        refreshCounter += 1
    }

    private func save() {
        try? modelContext.save()
        refreshCounter += 1
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        BadgeManager.updateBadge(unreadCount: unreadCount(for: .today))
        rescheduleNotifications()
    }
}
