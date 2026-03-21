# マンガ曜日

曜日ごとのマンガをワンタップで起動できるアプリです。

週間連載のマンガを曜日ごとに登録して、今日読むマンガをすぐに開けます。

## 機能

- 曜日ごとにマンガのURLを登録・管理
- ワンタップでマンガサイトやアプリを起動
- リスト表示 / Pinterest風グリッド表示（Masonryレイアウト）
- ホーム画面・ロック画面ウィジェット（曜日切り替えボタン付き）
- iCloud同期（iPhone / iPad / Mac / Apple Vision Pro）
- Share Extension（他アプリから共有してマンガを登録、OGP画像・掲載誌を自動取得）
- Apple Intelligence Foundation Modelによるマンガタイトル自動抽出
- iOSショートカット連携（AppIntent）
- バックアップ・インポート（JSON形式）
- 掲載誌フィルタリング
- ドラッグ&ドロップで並び替え
- 設定画面（バージョン表示、データリセット）

## 対応プラットフォーム

- iOS 26.0+
- iPadOS 26.0+
- macOS 26.0+（Designed for iPad）
- visionOS 26.0+

## 技術スタック

- Swift / SwiftUI
- SwiftData + CloudKit
- WidgetKit
- AppIntents
- FoundationModels（Apple Intelligence）

## ビルド

```bash
xcodebuild -project MangaLauncher.xcodeproj -scheme MangaLauncher -destination 'generic/platform=iOS' build
```

## ライセンス

MIT License
