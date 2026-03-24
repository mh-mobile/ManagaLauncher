# マンガ曜日

<img src="MangaLauncher/Assets.xcassets/AppIcon.appiconset/icon.png" width="128" alt="マンガ曜日 アプリアイコン">

曜日ごとのマンガをワンタップで起動できるアプリです。

週間連載のマンガを曜日ごとに登録して、今日読むマンガをすぐに開けます。

[![App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/ja-jp)](https://apps.apple.com/jp/app/%E3%83%9E%E3%83%B3%E3%82%AC%E6%9B%9C%E6%97%A5/id6760709060)

## 機能

- 曜日ごとにマンガのURLを登録・管理
- ワンタップでマンガサイトやアプリを起動
- リスト表示 / Pinterest風グリッド表示（Masonryレイアウト）
- 未読・既読管理（曜日ごとに自動リセット）
- キャッチアップUI（Tinder風カードスワイプで未読マンガをチェック）
- ホーム画面・ロック画面ウィジェット（Small / Medium / Large、曜日切り替え・未読ドット付き）
- アプリアイコンバッジに本日の未読数を表示
- 更新通知（マンガ登録がある曜日の指定時間にリマインド）
- iCloud同期（iPhone / iPad / Mac / Apple Vision Pro）
- Share Extension（他アプリやX投稿から共有してマンガを登録、OGP画像・掲載誌を自動取得）
- Apple Intelligence Foundation Modelによるマンガタイトル自動抽出
- iOSショートカット連携（AppIntent）
- 削除Undo（5秒間の取り消し猶予）
- バックアップ・インポート（JSON形式）
- 掲載誌フィルタリング
- ドラッグ&ドロップで並び替え
- 画像クロップ機能

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
- UserNotifications

## ビルド

```bash
xcodebuild -project MangaLauncher.xcodeproj -scheme MangaLauncher -destination 'generic/platform=iOS' build
```

## ライセンス

MIT License
