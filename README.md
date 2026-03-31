# マンガ曜日

<img src="MangaLauncher/Assets.xcassets/AppIcon.appiconset/icon.png" width="128" alt="マンガ曜日 アプリアイコン">

曜日ごとのマンガをワンタップで起動できるアプリです。

週間連載のマンガを曜日ごとに登録して、今日読むマンガをすぐに開けます。

[![App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/ja-jp)](https://apps.apple.com/jp/app/%E3%83%9E%E3%83%B3%E3%82%AC%E6%9B%9C%E6%97%A5/id6760709060)

## 主要機能

- **曜日管理** - 曜日ごとにマンガのURLを登録・ワンタップで起動
- **キャッチアップ** - Tinder風カードスワイプで未読マンガを一括チェック
- **壁紙** - プリセットカラー / カスタムカラー / 写真から好みの背景を設定
- **更新スケジュール** - 毎週 / 隔週 / 月1回 / カスタム間隔で更新頻度を管理
- **グリッド表示** - Pinterest風Masonryレイアウト、画面幅に応じて2〜4列の可変レスポンシブ
- **ウィジェット** - ホーム画面・ロック画面に対応（Small / Medium / Large）
- **iCloud同期** - iPhone / iPad / Mac / Apple Vision Pro 間でデータを同期

## その他の機能

- リスト表示 / グリッド表示の切り替え
- 未読・既読管理（曜日ごとに自動リセット）
- アプリアイコンバッジに本日の未読数を表示
- 更新通知（マンガ登録がある曜日の指定時間にリマインド）
- Share Extension（他アプリから共有してマンガを登録、OGP画像・掲載誌を自動取得）
- Apple Intelligence Foundation Modelによるマンガタイトル自動抽出
- iOSショートカット連携（AppIntent）
- ドラッグ&ドロップで並び替え・曜日間の移動
- グリッド編集モード（ブルブルアニメーション）
- 掲載誌フィルタリング
- アプリ内ブラウザ / デフォルトブラウザの選択
- 削除Undo（取り消し猶予）
- バックアップ・インポート（JSON形式）
- 画像クロップ機能
- オンボーディング / キャッチアップチュートリアル
- iPadレイアウト最適化

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

## モジュール構成

機能ごとにローカルSPMパッケージに分離しています。

| パッケージ | 概要 | 依存 |
|---|---|---|
| **PlatformKit** | 画像変換・リサイズ、VisualEffectBlur、Color拡張 | - |
| **WallpaperKit** | 壁紙管理・選択UI・クロップ | PlatformKit |
| **OGPKit** | OGPメタデータ取得・URL解決 | PlatformKit |
| **MangaExtractorKit** | Foundation ModelsによるAI抽出 | - |
| **NotificationKit** | 通知スケジュール・バッジ管理 | - |
| **CloudSyncKit** | iCloud同期監視 | - |

```
MangaLauncher (メインアプリ)
├── PlatformKit          ← 基盤（画像・UI共通）
├── WallpaperKit         ← 壁紙機能（→PlatformKit）
├── OGPKit               ← OGP取得（→PlatformKit）
├── MangaExtractorKit    ← AI抽出
├── NotificationKit      ← 通知・バッジ
└── CloudSyncKit         ← iCloud同期
```

## ビルド

```bash
# 開発ビルド
xcodebuild -project MangaLauncher.xcodeproj -scheme MangaLauncher -destination 'generic/platform=iOS' build

# Adhoc OTA配布（Tailscale HTTPS経由）
./scripts/ota-distribute.sh
```

## ライセンス

MIT License
