import Foundation

struct MangaLifetime: Identifiable {
    let entry: MangaEntry
    let startDate: Date
    let endDate: Date
    let activityCount: Int
    var id: UUID { entry.id }

    var isActive: Bool {
        entry.readingState != .archived && entry.publicationStatus != .finished
    }
}

enum LifetimeBuilder {
    static func build(
        entries: [MangaEntry],
        activities: [ReadingActivity],
        comments: [MangaComment]
    ) -> [MangaLifetime] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var activityDatesByEntry: [UUID: [Date]] = [:]

        for activity in activities {
            activityDatesByEntry[activity.mangaEntryID, default: []].append(activity.date)
        }
        for comment in comments {
            activityDatesByEntry[comment.mangaEntryID, default: []].append(comment.createdAt)
        }
        for entry in entries {
            if let memoDate = entry.memoUpdatedAt, !entry.memo.isEmpty {
                activityDatesByEntry[entry.id, default: []].append(memoDate)
            }
        }

        let entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })

        return activityDatesByEntry.compactMap { entryID, dates in
            guard let entry = entriesByID[entryID],
                  let earliest = dates.min(),
                  let latest = dates.max() else { return nil }

            let startDate = calendar.startOfDay(for: earliest)
            let endDate: Date
            if entry.readingState == .archived || entry.publicationStatus == .finished {
                endDate = calendar.startOfDay(for: latest)
            } else {
                endDate = today
            }

            let minEndDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            return MangaLifetime(
                entry: entry,
                startDate: startDate,
                endDate: max(minEndDate, endDate),
                activityCount: dates.count
            )
        }
        .sorted {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.entry.name < $1.entry.name
        }
    }
}
