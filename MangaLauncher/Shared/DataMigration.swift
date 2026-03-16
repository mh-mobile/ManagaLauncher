import Foundation

enum DataMigration {
    private static let migrationKey = "DataMigrationCompleted_v1"

    static func migrateToAppGroupIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        guard SharedModelContainer.appGroupContainerURL != nil else { return }

        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        // SwiftData default store path
        let oldStoreURL = appSupportURL.appendingPathComponent("default.store")
        guard fileManager.fileExists(atPath: oldStoreURL.path) else {
            // No existing data to migrate
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let newStoreURL = SharedModelContainer.storeURL

        // Don't overwrite if destination already exists
        guard !fileManager.fileExists(atPath: newStoreURL.path) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // Ensure destination directory exists
        let destDir = newStoreURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Copy SQLite files
        let suffixes = ["", "-wal", "-shm"]
        var allCopied = true
        for suffix in suffixes {
            let src = URL(fileURLWithPath: oldStoreURL.path + suffix)
            let dst = URL(fileURLWithPath: newStoreURL.path + suffix)
            guard fileManager.fileExists(atPath: src.path) else { continue }
            do {
                try fileManager.copyItem(at: src, to: dst)
            } catch {
                allCopied = false
                break
            }
        }

        // Copy external storage directory (for @Attribute(.externalStorage) imageData)
        if allCopied {
            let externalStorageDirs = [
                ".default_SUPPORT",
                ".MangaLauncher_SUPPORT"
            ]
            for dirName in externalStorageDirs {
                let srcExternal = appSupportURL.appendingPathComponent(dirName)
                let dstExternal = destDir.appendingPathComponent(dirName)
                if fileManager.fileExists(atPath: srcExternal.path) {
                    try? fileManager.copyItem(at: srcExternal, to: dstExternal)
                }
            }
        }

        if allCopied {
            UserDefaults.standard.set(true, forKey: migrationKey)
        } else {
            // Rollback: remove partially copied files
            for suffix in suffixes {
                let dst = URL(fileURLWithPath: newStoreURL.path + suffix)
                try? fileManager.removeItem(at: dst)
            }
        }
    }
}
