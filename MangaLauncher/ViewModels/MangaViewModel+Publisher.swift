import Foundation
import SwiftData

// MARK: - Publisher & Publisher Metadata

extension MangaViewModel {

    func allPublishers() -> [String] {
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let entries = modelContext.fetchLogged(descriptor)
        let currentHiddenIDs = hiddenIDs
        let currentDeletedIDs = deletedIDs
        let publishers = Set(entries.filter { !currentHiddenIDs.contains($0.id) && !currentDeletedIDs.contains($0.id) }.map(\.publisher)).filter { !$0.isEmpty }
        return publishers.sorted()
    }

    /// 掲載誌を統合する。`from` の名前を持つ全エントリの publisher を `to` に一括変更する。
    /// soft-delete されたエントリも含めて変更するのは、restore したときに「古い publisher 名で蘇る」
    /// ゴーストを作らないため（統合は user の所有データ全体に対する操作と捉える）。
    /// 統合元の `PublisherMetadata`（アイコン情報）も削除する。統合先の metadata はそのまま維持。
    func mergePublisher(from oldName: String, to newName: String) {
        guard !oldName.isEmpty, !newName.isEmpty, oldName != newName else { return }
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.publisher == oldName }
        )
        let entries = modelContext.fetchLogged(descriptor)
        guard !entries.isEmpty else { return }
        for entry in entries {
            entry.publisher = newName
        }
        // 統合元の metadata を削除（統合先のアイコンを維持）
        deletePublisherMetadata(name: oldName)
        save()
    }

    /// `mergePublisher` の前置確認用。統合される件数（soft-delete 込み）を返す。
    func mergePublisherPreviewCount(for oldName: String) -> Int {
        guard !oldName.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<MangaEntry>(
            predicate: #Predicate { $0.publisher == oldName }
        )
        return modelContext.fetchLogged(descriptor).count
    }

    // MARK: Publisher Metadata

    /// 指定 publisher のアイコン Data を取得（表示パスから毎回呼ばれる前提、軽量）。
    func publisherIcon(for name: String) -> Data? {
        guard !name.isEmpty else { return nil }
        return loadAllPublisherIcons()[name] ?? nil
    }

    /// 指定 publisher にアイコンが設定されているか。
    func publisherHasIcon(name: String) -> Bool {
        guard !name.isEmpty else { return false }
        // loadAllPublisherIcons() は [String: Data?] なので添字は Data?? を返す。
        // ?? nil で Data? にフラット化し、実際に iconData がある場合のみ true にする。
        return (loadAllPublisherIcons()[name] ?? nil) != nil
    }

    /// publisher 名 → iconData の辞書を返す（キャッシュ済みならそれを返す）。
    private func loadAllPublisherIcons() -> [String: Data?] {
        invalidateCacheIfStale()
        if let cached = cachedPublisherIcons { return cached }
        let descriptor = FetchDescriptor<PublisherMetadata>()
        let records = modelContext.fetchLogged(descriptor)
        let sorted = records.sorted { lhs, rhs in
            let lhsHas = lhs.iconData != nil
            let rhsHas = rhs.iconData != nil
            if lhsHas != rhsHas { return lhsHas }
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }
        var result: [String: Data?] = [:]
        for record in sorted where result[record.name] == nil {
            result[record.name] = record.iconData
        }
        cachedPublisherIcons = result
        return result
    }

    /// 指定 publisher のメタデータレコード。重複時は iconData 持ち + 新しい updatedAt を優先。
    private func publisherMetadata(for name: String) -> PublisherMetadata? {
        let descriptor = FetchDescriptor<PublisherMetadata>(
            predicate: #Predicate { $0.name == name }
        )
        let results = modelContext.fetchLogged(descriptor)
        if results.count <= 1 { return results.first }
        return results.sorted { lhs, rhs in
            let lhsHas = lhs.iconData != nil
            let rhsHas = rhs.iconData != nil
            if lhsHas != rhsHas { return lhsHas }
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }.first
    }

    /// アイコンを保存。
    func setPublisherIcon(name: String, imageData: Data, sourceURL: String? = nil) {
        guard !name.isEmpty else { return }
        if let existing = publisherMetadata(for: name) {
            existing.iconData = imageData
            if let sourceURL { existing.sourceURL = sourceURL }
            existing.updatedAt = Date()
        } else {
            let meta = PublisherMetadata(name: name, iconData: imageData, sourceURL: sourceURL)
            modelContext.insert(meta)
        }
        save()
    }

    /// アイコンのみクリア。
    func clearPublisherIcon(name: String) {
        guard !name.isEmpty else { return }
        let descriptor = FetchDescriptor<PublisherMetadata>(
            predicate: #Predicate { $0.name == name }
        )
        let records = modelContext.fetchLogged(descriptor)
        guard !records.isEmpty else { return }
        let now = Date()
        for meta in records {
            meta.iconData = nil
            meta.updatedAt = now
        }
        save()
    }

    /// メタデータレコードを完全削除（mergePublisher 用）。
    private func deletePublisherMetadata(name: String) {
        let descriptor = FetchDescriptor<PublisherMetadata>(
            predicate: #Predicate { $0.name == name }
        )
        for meta in modelContext.fetchLogged(descriptor) {
            modelContext.delete(meta)
        }
    }
}
