# マンガ曜日

曜日ごとのマンガをワンタップで起動できるアプリです。

週間連載のマンガを曜日ごとに登録して、今日読むマンガをすぐに開けます。

## 機能

- 曜日ごとにマンガのURLを登録・管理
- ワンタップでマンガサイトやアプリを起動
- リスト表示 / Pinterest風グリッド表示
- ホーム画面・ロック画面ウィジェット
- iCloud同期（iPhone / iPad / Mac / Apple Vision Pro）
- バックアップ・インポート（JSON形式）
- 掲載誌フィルタリング
- ドラッグ&ドロップで並び替え

## 対応プラットフォーム

- iOS 17.0+
- iPadOS 17.0+
- macOS 14.0+（Designed for iPad）
- visionOS 2.0+

## 技術スタック

- Swift / SwiftUI
- SwiftData + CloudKit
- WidgetKit

## ビルド

```bash
xcodebuild -project MangaLauncher.xcodeproj -scheme MangaLauncher -destination 'generic/platform=iOS' build
```

## ライセンス

MIT License
