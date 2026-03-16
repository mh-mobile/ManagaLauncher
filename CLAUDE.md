# MangaLauncher

マンガの更新曜日ごとにURLを管理・起動するiOSアプリ。

## 技術スタック

- Swift / SwiftUI
- SwiftData (永続化)
- Xcode プロジェクト (SPM/CocoaPods未使用)
- 対象: iOS

## プロジェクト構成

```
MangaLauncher/
├── MangaLauncherApp.swift     # エントリポイント
├── Models/
│   └── MangaEntry.swift       # データモデル (MangaEntry, DayOfWeek)
├── ViewModels/
│   └── MangaViewModel.swift   # ビジネスロジック
├── Views/
│   ├── ContentView.swift      # メイン画面 (曜日タブ + リスト)
│   ├── EditEntryView.swift    # 新規登録・編集画面
│   └── PublisherPickerView.swift  # 掲載誌選択
└── Assets.xcassets/
```

## データモデル

- `MangaEntry`: SwiftData `@Model` - name, url, dayOfWeekRawValue, sortOrder, iconColor, publisher, imageData
- `DayOfWeek`: Int enum (0=日〜6=土), `shortName`(日/月/...)、`displayName`(日曜日/月曜日/...)

## ビルド

```bash
xcodebuild -project MangaLauncher.xcodeproj -scheme MangaLauncher -destination 'generic/platform=iOS' build
```

## Git

- リモート: `origin` → `git@github.com:mh-mobile/ManagaLauncher.git`
- ブランチ: `main`
