import Foundation
import Observation
import SwiftData
import NotificationKit
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
        let descriptor: FetchDescriptor<MangaEntry>
        if day.isHiatus {
            descriptor = FetchDescriptor<MangaEntry>(
                predicate: #Predicate { $0.isOnHiatus },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
        } else {
            let dayRawValue = day.rawValue
            descriptor = FetchDescriptor<MangaEntry>(
                predicate: #Predicate { $0.dayOfWeekRawValue == dayRawValue && !$0.isOnHiatus },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
        }
        let results = (try? modelContext.fetch(descriptor)) ?? []
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        var seenIDs = Set<UUID>()
        return results.filter { entry in
            guard !pendingIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }
    }

    func toggleHiatus(_ entry: MangaEntry) {
        entry.isOnHiatus.toggle()
        save()
    }

    func addEntry(name: String, url: String, days: Set<DayOfWeek>, iconColor: String, publisher: String = "", imageData: Data? = nil, updateIntervalWeeks: Int = 1, nextExpectedUpdate: Date? = nil) {
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
                imageData: imageData,
                updateIntervalWeeks: updateIntervalWeeks
            )
            entry.nextExpectedUpdate = nextExpectedUpdate
            modelContext.insert(entry)
        }
        save()
    }

    func updateEntry(_ entry: MangaEntry, name: String, url: String, dayOfWeek: DayOfWeek, iconColor: String, publisher: String = "", imageData: Data? = nil, updateIntervalWeeks: Int = 1, nextExpectedUpdate: Date? = nil) {
        entry.name = name
        entry.url = url
        entry.dayOfWeek = dayOfWeek
        entry.iconColor = iconColor
        entry.publisher = publisher
        entry.imageData = imageData
        entry.updateIntervalWeeks = updateIntervalWeeks
        entry.nextExpectedUpdate = nextExpectedUpdate
        save()
    }

    func publishers(for day: DayOfWeek) -> [String] {
        let entries = fetchEntries(for: day)
        return Set(entries.map(\.publisher)).filter { !$0.isEmpty }.sorted()
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

    func moveEntryToDay(_ entry: MangaEntry, to newDay: DayOfWeek, at targetEntry: MangaEntry? = nil) {
        if newDay.isHiatus {
            entry.isOnHiatus = true
        } else {
            entry.isOnHiatus = false
            entry.dayOfWeek = newDay
            entry.resetNextUpdate()
        }
        var entries = fetchEntries(for: newDay)
        if !entries.contains(where: { $0.id == entry.id }) {
            if let targetEntry, let targetIndex = entries.firstIndex(where: { $0.id == targetEntry.id }) {
                entries.insert(entry, at: targetIndex)
            } else {
                entries.append(entry)
            }
        }
        for (index, e) in entries.enumerated() {
            e.sortOrder = index
        }
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

    func deleteAllEntries() {
        let descriptor = FetchDescriptor<MangaEntry>()
        guard let entries = try? modelContext.fetch(descriptor) else { return }
        for entry in entries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
        refreshCounter += 1
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        BadgeManager.updateBadge(unreadCount: 0)
        NotificationManager.scheduleNotifications(entryCounts: [:], dayDisplayNames: [:])
    }

    func totalEntryCount() -> Int {
        let _ = refreshCounter
        let descriptor = FetchDescriptor<MangaEntry>()
        let results = (try? modelContext.fetch(descriptor)) ?? []
        let pendingIDs = Set(pendingDeleteEntries.map(\.id))
        var seenIDs = Set<UUID>()
        return results.filter { entry in
            guard !pendingIDs.contains(entry.id) else { return false }
            return seenIDs.insert(entry.id).inserted
        }.count
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
                imageData: backupEntry.imageData,
                updateIntervalWeeks: backupEntry.updateIntervalWeeks
            )
            entry.lastReadDate = backupEntry.lastReadDate
            entry.nextExpectedUpdate = backupEntry.nextExpectedUpdate
            entry.isOnHiatus = backupEntry.isOnHiatus ?? false
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
        entry.advanceToNextUpdate()
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
        var counts: [Int: Int] = [:]
        var displayNames: [Int: String] = [:]
        for day in DayOfWeek.orderedDays {
            counts[day.rawValue] = fetchEntries(for: day).count
            displayNames[day.rawValue] = day.displayName
        }
        NotificationManager.scheduleNotifications(entryCounts: counts, dayDisplayNames: displayNames)
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
