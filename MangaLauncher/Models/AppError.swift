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
}
