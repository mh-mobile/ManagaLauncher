import Foundation

/// アプリ全体で扱う重大エラー。MangaViewModel.lastError に格納し、
/// View 側で alert 表示する。
struct AppError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func migration(_ underlying: Error) -> AppError {
        AppError(
            title: "データ移行エラー",
            message: "古いデータの移行に失敗しました。\n\(underlying.localizedDescription)"
        )
    }

    static func backupImport(_ message: String) -> AppError {
        AppError(title: "インポート失敗", message: message)
    }

    static func backupExport(_ underlying: Error) -> AppError {
        AppError(
            title: "エクスポート失敗",
            message: underlying.localizedDescription
        )
    }

    static func save(_ underlying: Error) -> AppError {
        AppError(
            title: "保存失敗",
            message: "データの保存に失敗しました。\n\(underlying.localizedDescription)"
        )
    }

    /// CloudKit の初期化に失敗してローカル only モードで起動したことをユーザーに通知する。
    /// このまま使えるが端末間同期は止まっている状態。
    static func cloudKitDisabled(_ underlying: Error) -> AppError {
        AppError(
            title: "iCloud 同期が無効になっています",
            message: "iCloud との接続に失敗したため、ローカル only モードで起動しました。"
                + "他端末との同期は行われません。\n\n"
                + "iCloud 設定を確認後、アプリを再起動してください。\n\n"
                + "詳細: \(underlying.localizedDescription)"
        )
    }
}
