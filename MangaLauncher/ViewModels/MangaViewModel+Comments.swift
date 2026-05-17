import Foundation
import SwiftData

// MARK: - Comments & Comment Undo Delete

extension MangaViewModel {

    func addComment(_ entry: MangaEntry, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = MangaComment(mangaEntryID: entry.id, content: trimmed)
        modelContext.insert(comment)
        save()
    }

    func updateComment(_ comment: MangaComment, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        comment.content = trimmed
        comment.updatedAt = Date()
        save()
    }

    func deleteComment(_ comment: MangaComment) {
        modelContext.delete(comment)
        save()
    }

    // MARK: Comment Undo Delete

    func queueDeleteComment(_ comment: MangaComment) {
        pendingDeleteComments.append(comment)
        refreshCounter += 1
        restartCommentDeleteTimer()
    }

    func undoPendingCommentDeletes() {
        commentDeleteTimer?.invalidate()
        commentDeleteTimer = nil
        pendingDeleteComments.removeAll()
        refreshCounter += 1
    }

    func commitPendingCommentDeletes() {
        commentDeleteTimer?.invalidate()
        commentDeleteTimer = nil
        for comment in pendingDeleteComments {
            modelContext.delete(comment)
        }
        pendingDeleteComments.removeAll()
        save()
    }

    func fetchComments(for entry: MangaEntry) -> [MangaComment] {
        let _ = refreshCounter
        let entryID = entry.id
        let descriptor = FetchDescriptor<MangaComment>(
            predicate: #Predicate { $0.mangaEntryID == entryID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let pendingIDs = Set(pendingDeleteComments.map(\.id))
        return modelContext.fetchLogged(descriptor).filter { !pendingIDs.contains($0.id) }
    }

    func allComments() -> [MangaComment] {
        invalidateCacheIfStale()
        if let cached = cachedComments { return cached }
        let descriptor = FetchDescriptor<MangaComment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let pendingIDs = Set(pendingDeleteComments.map(\.id))
        let result = modelContext.fetchLogged(descriptor).filter { !pendingIDs.contains($0.id) }
        cachedComments = result
        return result
    }
}
