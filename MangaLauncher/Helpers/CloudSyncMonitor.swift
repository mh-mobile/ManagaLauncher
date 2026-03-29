import Foundation
import CoreData
import Observation

enum CloudSyncStatus: Equatable {
    case idle
    case syncing
    case failed(String)
    case notAvailable

    static func == (lhs: CloudSyncStatus, rhs: CloudSyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.notAvailable, .notAvailable):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

@Observable
final class CloudSyncMonitor {
    private(set) var syncStatus: CloudSyncStatus = .idle
    private(set) var lastSyncDate: Date?

    init() {
        startMonitoring()
        checkAccountStatus()
    }

    private func startMonitoring() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentCloudKitContainerEventChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSyncEvent(notification)
        }
    }

    private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?["event"] as? NSObject else { return }

        let endDate = event.value(forKey: "endDate") as? Date
        let succeeded = (event.value(forKey: "succeeded") as? Bool) ?? false
        let error = event.value(forKey: "error") as? NSError

        if endDate == nil {
            syncStatus = .syncing
        } else if succeeded {
            lastSyncDate = endDate
            syncStatus = .idle
            // import(type=1)完了時にデータ変更を通知
            let eventType = (event.value(forKey: "type") as? Int) ?? 0
            if eventType == 1 {
                NotificationCenter.default.post(name: .mangaDataDidChange, object: nil)
            }
        } else if let error {
            let eventType = (event.value(forKey: "type") as? Int).map { String($0) } ?? "?"
            let detail = "\(error.domain) code=\(error.code) type=\(eventType): \(error.localizedDescription)"
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                syncStatus = .failed("\(detail)\n↳ \(underlying.domain) code=\(underlying.code): \(underlying.localizedDescription)")
            } else {
                syncStatus = .failed(detail)
            }
        }
    }

    private func checkAccountStatus() {
        #if canImport(CloudKit)
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.mh-mobile.MangaYoubi")
                let status = try await container.accountStatus()
                if status != .available {
                    await MainActor.run {
                        syncStatus = .notAvailable
                    }
                }
            } catch {}
        }
        #endif
    }
}

#if canImport(CloudKit)
import CloudKit
#endif
