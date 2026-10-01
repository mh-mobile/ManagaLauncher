import Foundation

/// body 内の重い計算を「バージョンが変わった時だけ」再実行するためのメモ化ボックス。
/// `@State` に保持して使う (参照型の中身書き換えは SwiftUI の再描画をトリガーしない)。
///
/// `@State`/`onAppear` へのキャッシュ移設と違い、body 内で version 値
/// (例: viewModel.refreshCounter) を読み続けるため Observation による
/// 「データ変更 → 再描画 → 再計算」のライブ更新挙動はそのまま維持される。
/// 無関係な State 変化による再レンダーでのみ再計算をスキップする。
public final class VersionedMemo<Value> {
    private var version: AnyHashable?
    private var value: Value?

    public init() {}

    public func callAsFunction(version: AnyHashable, compute: () -> Value) -> Value {
        if let value, self.version == version {
            return value
        }
        let newValue = compute()
        self.version = version
        self.value = newValue
        return newValue
    }
}
