import SwiftUI

/// allEntries から LibrarySection の配列を組み立てる責務をライブラリ画面から分離。
/// 各セクションごとに小さなメソッドに分かれており、追加・削除がしやすい。
struct LibrarySectionBuilder {
    let allEntries: [MangaEntry]

    func build() -> [LibrarySection] {
        var sections: [LibrarySection] = []
        sections.append(contentsOf: [
            recentSection(),
            unreadSection(),
            backlogSection(),
        ].compactMap { $0 })
        sections.append(contentsOf: colorLabelSections())
        sections.append(contentsOf: [
            serialSection(),
            oneShotSection(),
            hiatusSection(),
            publicationFinishedSection(),
            archivedSection(),
        ].compactMap { $0 })
        sections.append(contentsOf: publisherSections())
        return sections
    }

    // MARK: - Sections

    /// 最近読んだ（直近 2 週間）
    private func recentSection() -> LibrarySection? {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        let recent = allEntries
            .filter { ($0.lastReadDate ?? .distantPast) >= twoWeeksAgo }
            .sorted { ($0.lastReadDate ?? .distantPast) > ($1.lastReadDate ?? .distantPast) }
        guard !recent.isEmpty else { return nil }
        return LibrarySection(title: "最近読んだ", icon: "clock.arrow.circlepath", entries: recent)
    }

    /// 未読（追っかけ中・連載中のみ）
    private func unreadSection() -> LibrarySection? {
        let unread = allEntries.filter {
            !$0.isRead
                && $0.readingState == .following
                && $0.publicationStatus == .active
        }
        guard !unread.isEmpty else { return nil }
        return LibrarySection(title: "未読", icon: "envelope.badge", entries: unread)
    }

    /// 積読
    private func backlogSection() -> LibrarySection? {
        let backlog = allEntries.filter { $0.readingState == .backlog }
        guard !backlog.isEmpty else { return nil }
        return LibrarySection(title: "積読", icon: "books.vertical", entries: backlog)
    }

    /// カラーラベル別（ラベル設定済みのもののみ）
    private func colorLabelSections() -> [LibrarySection] {
        let colorLabels = ColorLabelStore.shared.labels
        return MangaColor.all.compactMap { mangaColor in
            guard let label = colorLabels[mangaColor.name], !label.isEmpty else { return nil }
            let entries = allEntries.filter { $0.iconColor == mangaColor.name }
            guard !entries.isEmpty else { return nil }
            return LibrarySection(
                title: label,
                icon: "tag.fill",
                iconColor: mangaColor.color,
                entries: entries
            )
        }
    }

    /// 連載中（追っかけ中のみ）
    private func serialSection() -> LibrarySection? {
        let serial = allEntries.filter {
            !$0.isOneShot
                && $0.publicationStatus == .active
                && $0.readingState == .following
        }
        guard !serial.isEmpty else { return nil }
        return LibrarySection(title: "連載中", icon: "book", entries: serial)
    }

    /// 読み切り（読書状況に関係なく全て。読了と重複表示 OK）
    private func oneShotSection() -> LibrarySection? {
        let oneShot = allEntries.filter { $0.isOneShot }
        guard !oneShot.isEmpty else { return nil }
        return LibrarySection(title: "読み切り", icon: "doc.text", entries: oneShot)
    }

    /// 休載中（読書状況に関係なく全て。読了と重複表示 OK）
    private func hiatusSection() -> LibrarySection? {
        let hiatus = allEntries.filter { $0.publicationStatus == .hiatus }
        guard !hiatus.isEmpty else { return nil }
        return LibrarySection(title: "休載中", icon: "moon.zzz", entries: hiatus)
    }

    /// 完結（読書状況に関係なく全て。読了と重複表示 OK）
    private func publicationFinishedSection() -> LibrarySection? {
        let finished = allEntries.filter { $0.publicationStatus == .finished }
        guard !finished.isEmpty else { return nil }
        return LibrarySection(title: "完結", icon: "flag.checkered", entries: finished)
    }

    /// 読了（読書アーカイブ）
    private func archivedSection() -> LibrarySection? {
        let archived = allEntries.filter { $0.readingState == .archived }
        guard !archived.isEmpty else { return nil }
        return LibrarySection(title: "読了", icon: "checkmark.seal", entries: archived)
    }

    /// 掲載誌別（登録数の多い順、上位5誌のみ。最初のセクションだけに「すべて表示」を付ける）
    private func publisherSections() -> [LibrarySection] {
        let sortedPublishers = PublisherIndex.counts(from: allEntries)
        let hasMore = sortedPublishers.count > 5
        return sortedPublishers.prefix(5).enumerated().compactMap { (index, item) -> LibrarySection? in
            let entries = allEntries.filter { $0.publisher == item.publisher }
            guard !entries.isEmpty else { return nil }
            return LibrarySection(
                title: item.publisher,
                icon: "magazine",
                entries: entries,
                seeAll: (index == 0 && hasMore) ? .allPublishers : nil
            )
        }
    }
}

/// 掲載誌ごとの集計を構築する純関数群。
enum PublisherIndex {
    /// 登録数の多い順に並べた (掲載誌, 件数) 配列。
    /// 同数の場合は掲載誌名の辞書順を tiebreaker に使うことで、
    /// Dictionary の列挙順の非決定性に左右されない安定した順序を返す。
    static func counts(from entries: [MangaEntry]) -> [(publisher: String, count: Int)] {
        let grouped = Dictionary(grouping: entries.filter { !$0.publisher.isEmpty }) { $0.publisher }
            .mapValues { $0.count }
        return grouped
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }
            .map { (publisher: $0.key, count: $0.value) }
    }
}
