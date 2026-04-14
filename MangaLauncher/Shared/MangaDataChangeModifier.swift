import SwiftUI

/// `mangaDataDidChange` 通知（CloudKit インポート完了 / 復帰 / Intent 経由更新時）を受信して
/// View 側で refresh をトリガーするためのモディファイア。
///
/// なぜ必要か:
/// - SwiftData の @Observable 追跡はローカルの mutation しか拾わない
/// - CloudKit インポートは persistence 層で行われるため Observation は反応しない
/// - 各画面が独立した `MangaViewModel` を持つため、それぞれで `refresh()` する必要がある
struct MangaDataChangeModifier: ViewModifier {
    let onChange: () -> Void

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .mangaDataDidChange)) { _ in
            onChange()
        }
    }
}

extension View {
    /// マンガデータが外部要因で変更されたとき（CloudKit sync など）に refresh を実行する。
    func onMangaDataChange(_ action: @escaping () -> Void) -> some View {
        modifier(MangaDataChangeModifier(onChange: action))
    }
}
