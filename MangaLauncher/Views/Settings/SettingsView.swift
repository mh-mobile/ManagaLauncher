import SwiftUI
import UniformTypeIdentifiers
import CloudSyncKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    var viewModel: MangaViewModel
    var showsCloseButton: Bool = true

    @State private var showingResetConfirmation = false
    @State private var achievementResetDone = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importResult: ImportResult?
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"
    @State private var updateStatus: UpdateStatus = .idle
    @State private var showingOnboarding = false
    @State private var showingSyncError = false
    @State private var currentThemeMode: ThemeMode = ThemeManager.shared.mode

    private enum UpdateStatus {
        case idle, checking, available(String), upToDate, error
    }

    private enum ImportResult: Identifiable {
        case success(Int)
        case failure

        var id: String {
            switch self {
            case .success: "success"
            case .failure: "failure"
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("登録数")
                        Spacer()
                        Text("\(viewModel.totalEntryCount())件")
                            .foregroundStyle(.secondary)
                    }
                    switch updateStatus {
                    case .idle:
                        Button("アップデートを確認") {
                            checkForUpdate()
                        }
                    case .checking:
                        HStack {
                            Text("確認中...")
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                        }
                    case .available(let version):
                        Link(destination: URL(string: "https://apps.apple.com/jp/app/%E3%83%9E%E3%83%B3%E3%82%AC%E6%9B%9C%E6%97%A5/id6760709060")!) {
                            HStack {
                                Text("v\(version)が利用可能です")
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    case .upToDate:
                        HStack {
                            Text("最新バージョンです")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    case .error:
                        Button("確認できませんでした（再試行）") {
                            checkForUpdate()
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section {
                    NavigationLink {
                        ReadingHeatmapView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("読書アクティビティ")
                        }
                    }
                    NavigationLink {
                        TimelineView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                            Text("タイムライン")
                        }
                    }
                }

                Section("iCloud同期") {
                    HStack {
                        syncStatusIcon
                        syncStatusText
                        Spacer()
                        if let date = syncMonitor.lastSyncDate {
                            Text(date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if case .failed = syncMonitor.syncStatus {
                            showingSyncError = true
                        }
                    }
                }

                Section {
                    Button {
                        showingExporter = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("バックアップ（エクスポート）")
                        }
                    }
                    .disabled(viewModel.totalEntryCount() == 0)

                    Button {
                        showingImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("インポート")
                        }
                    }
                } header: {
                    Text("データ管理")
                } footer: {
                    Text("バックアップはJSON形式で保存されます。インポート時、同じIDのエントリはスキップされます。")
                }

                Section {
                    Picker("テーマ", selection: $currentThemeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                        }
                    }
                } header: {
                    Text("テーマ")
                } footer: {
                    Text("「Kinetic Ink」はマンガ風のダークテーマ、「レトロ」は70〜80年代の劇画誌をイメージしたテーマです。")
                }

                Section {
                    NavigationLink {
                        ColorLabelSettingsView()
                    } label: {
                        Label("カラーラベル", systemImage: "tag")
                    }
                } header: {
                    Text("カラーラベル")
                } footer: {
                    Text("カラーアイコンに任意の名前を付けると、検索フィルターで使用できます（例：赤=お気に入り）")
                }

                Section {
                    Picker("ブラウザ", selection: $browserMode) {
                        Text("アプリ内（Safari）").tag("inApp")
                        Text("デフォルトブラウザ").tag("external")
                    }
                } header: {
                    Text("ブラウザ")
                } footer: {
                    Text("「アプリ内」はSafariベースのブラウザで表示します。「デフォルトブラウザ」はiOSで設定したブラウザで開きます。")
                }

                NotificationSection(viewModel: viewModel)

                ShortcutsSection()

                Section {
                    Button("アプリについて") {
                        showingOnboarding = true
                    }
                    NavigationLink("ライセンス") {
                        LicenseListView()
                    }
                }

                #if DEBUG
                Section("デバッグ") {
                    Button {
                        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastStreakShownDate)
                        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.shownMilestones)
                        achievementResetDone = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.feedbackDuration) {
                            achievementResetDone = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text(achievementResetDone ? "リセットしました" : "アチーブメント記録をリセット")
                        }
                    }
                }
                #endif

                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("すべてのデータを削除")
                        }
                    }
                    .disabled(viewModel.totalEntryCount() == 0)
                } footer: {
                    Text("登録されたすべてのマンガデータを削除します。この操作は取り消せません。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(currentThemeMode.style.groupedBackground)
            .toolbarBackground(currentThemeMode.style.toolbarBackgroundVisibility, for: .navigationBar)
            .toolbarColorScheme(currentThemeMode.style.resolvedColorScheme(system: systemColorScheme), for: .navigationBar)
            .navigationTitle("設定")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("データをリセット", isPresented: $showingResetConfirmation) {
                Button("削除", role: .destructive) {
                    viewModel.deleteAllEntries()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("すべてのマンガデータが削除されます。この操作は取り消せません。")
            }
            .alert(item: $importResult) { result in
                switch result {
                case .success(let count):
                    Alert(
                        title: Text("インポート完了"),
                        message: Text("\(count)件のエントリをインポートしました。"),
                        dismissButton: .default(Text("OK"))
                    )
                case .failure:
                    Alert(
                        title: Text("インポート失敗"),
                        message: Text("ファイルを読み込めませんでした。正しいバックアップファイルか確認してください。"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument(),
                contentType: .json,
                defaultFilename: "MangaLauncher_backup"
            ) { _ in }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .alert("同期エラー", isPresented: $showingSyncError) {
                Button("OK") {}
            } message: {
                if case .failed(let message) = syncMonitor.syncStatus {
                    Text(message)
                }
            }
        }
        .preferredColorScheme(currentThemeMode.style.resolvedColorScheme(system: systemColorScheme))
        .onChange(of: currentThemeMode) { _, newValue in
            ThemeManager.shared.mode = newValue
        }
    }

    @ViewBuilder
    private var syncStatusIcon: some View {
        switch syncMonitor.syncStatus {
        case .idle:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.green)
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .symbolEffect(.rotate, isActive: true)
                .foregroundStyle(.blue)
        case .failed:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.red)
        case .notAvailable:
            Image(systemName: "xmark.icloud")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var syncStatusText: some View {
        switch syncMonitor.syncStatus {
        case .idle:
            Text("同期済み")
        case .syncing:
            Text("同期中...")
        case .failed:
            Text("同期エラー")
                .foregroundStyle(.red)
        case .notAvailable:
            Text("iCloud未設定")
                .foregroundStyle(.secondary)
        }
    }

    private func checkForUpdate() {
        updateStatus = .checking
        Task {
            guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=com.mh-mobile.MangaYoubi&country=jp") else {
                updateStatus = .error
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["results"] as? [[String: Any]],
                      let latest = results.first,
                      let storeVersion = latest["version"] as? String else {
                    updateStatus = .error
                    return
                }
                if storeVersion.compare(appVersion, options: .numeric) == .orderedDescending {
                    updateStatus = .available(storeVersion)
                } else {
                    updateStatus = .upToDate
                }
            } catch {
                updateStatus = .error
            }
        }
    }

    private func exportDocument() -> BackupDocument {
        let data = viewModel.exportBackupData() ?? Data()
        return BackupDocument(data: data)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            importResult = .failure
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            importResult = .failure
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            importResult = .failure
            return
        }
        let count = viewModel.importBackupData(data)
        importResult = .success(count)
    }
}
