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

                Section("ライセンス") {
                    NavigationLink("Mantis") {
                        LicenseDetailView(
                            name: "Mantis",
                            licenseText: """
                            MIT License

                            Copyright (c) 2018 Yingtao Guo

                            Permission is hereby granted, free of charge, to any person obtaining a copy \
                            of this software and associated documentation files (the "Software"), to deal \
                            in the Software without restriction, including without limitation the rights \
                            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                            copies of the Software, and to permit persons to whom the Software is \
                            furnished to do so, subject to the following conditions:

                            The above copyright notice and this permission notice shall be included in all \
                            copies or substantial portions of the Software.

                            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
                            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
                            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
                            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
                            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
                            SOFTWARE.
                            """
                        )
                    }
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

    private struct LicenseDetailView: View {
        let name: String
        let licenseText: String

        var body: some View {
            ScrollView {
                Text(licenseText)
                    .font(.caption)
                    .monospaced()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(name)
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
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
