import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: MangaViewModel

    @State private var showingResetConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
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
        }
    }
}
