import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: MangaViewModel

    @State private var showingResetConfirmation = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importResult: ImportResult?

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
            .navigationTitle("設定")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("データをリセット", isPresented: $showingResetConfirmation) {
                Button("削除", role: .destructive) {
                    viewModel.deleteAllEntries()
                    dismiss()
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
