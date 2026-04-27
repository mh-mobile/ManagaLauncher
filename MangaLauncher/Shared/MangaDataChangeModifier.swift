import SwiftUI
import Combine

/// `mangaDataDidChange` 通知（CloudKit インポート完了 / 復帰 / Intent 経由更新時）を受信して
/// View 側で refresh をトリガーするためのモディファイア。
///
/// なぜ必要か:
/// - SwiftData の @Observable 追跡はローカルの mutation しか拾わない
/// - CloudKit インポートは persistence 層で行われるため Observation は反応しない
/// - 各画面が独立した `MangaViewModel` を持つため、それぞれで `refresh()` する必要がある
///
/// debounce (0.5s) により短時間に連続する通知を1回にまとめる。
struct MangaDataChangeModifier: ViewModifier {
    let onChange: () -> Void

    func body(content: Content) -> some View {
        content.onReceive(
            NotificationCenter.default.publisher(for: .mangaDataDidChange)
                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        ) { _ in
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
