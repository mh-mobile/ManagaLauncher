import Foundation
import SwiftData

// MARK: - Links

extension MangaViewModel {

    func addLink(_ entry: MangaEntry, linkType: LinkType, title: String, url: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        let existingLinks = fetchLinks(for: entry)
        let nextOrder = (existingLinks.map(\.sortOrder).max() ?? -1) + 1
        let link = MangaLink(
            mangaEntryID: entry.id,
            linkType: linkType,
            title: trimmedTitle,
            url: trimmedURL,
            sortOrder: nextOrder
        )
        modelContext.insert(link)
        save()
    }

    func updateLink(_ link: MangaLink, linkType: LinkType, title: String, url: String) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        link.linkType = linkType
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        link.url = trimmedURL
        link.updatedAt = Date()
        save()
    }

    func deleteLink(_ link: MangaLink) {
        modelContext.delete(link)
        save()
    }

    func fetchLinks(for entry: MangaEntry) -> [MangaLink] {
        let _ = refreshCounter
        let entryID = entry.id
        let descriptor = FetchDescriptor<MangaLink>(
            predicate: #Predicate { $0.mangaEntryID == entryID },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return modelContext.fetchLogged(descriptor)
    }

    func moveLinks(for entry: MangaEntry, from source: IndexSet, to destination: Int) {
        var links = fetchLinks(for: entry)
        links.move(fromOffsets: source, toOffset: destination)
        for (index, link) in links.enumerated() {
            link.sortOrder = index
        }
        save()
    }
}
