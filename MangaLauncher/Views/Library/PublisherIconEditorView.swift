import SwiftUI
import PhotosUI
import PlatformKit

/// 掲載誌アイコンの設定シート。
/// カメラロール / URL ファビコン取得 の 2 経路を提供し、プレビューを確認してから保存する。
struct PublisherIconEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let publisherName: String
    var viewModel: MangaViewModel

    enum Mode: Hashable { case photo, url }

    @State private var mode: Mode = .photo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var urlInput: String = ""
    @State private var isFetching = false
    @State private var errorMessage: String?
    /// 未保存のプレビュー画像。nil の場合は既存設定（または fallback）を表示。
    @State private var previewData: Data?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var displayedIconData: Data? {
        previewData ?? viewModel.publisherIcon(for: publisherName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PublisherIconView(
                            iconData: displayedIconData,
                            size: 96,
                            showsFallback: true
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text("プレビュー")
                }

                Section {
                    Picker("取得方法", selection: $mode) {
                        Text("カメラロール").tag(Mode.photo)
                        Text("URL から取得").tag(Mode.url)
                    }
                    .pickerStyle(.segmented)
                }

                switch mode {
                case .photo:
                    Section {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("写真を選ぶ", systemImage: "photo")
                        }
                    } footer: {
                        Text("中央を正方形に切り抜いて保存します")
                    }
                case .url:
                    Section {
                        TextField("https://example.com", text: $urlInput)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .autocorrectionDisabled()
                        Button {
                            fetchFromURL()
                        } label: {
                            HStack {
                                if isFetching {
                                    ProgressView()
                                    Text("取得中...")
                                } else {
                                    Label("ファビコンを取得", systemImage: "link")
                                }
                            }
                        }
                        .disabled(isFetching || urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    } footer: {
                        Text("掲載誌の公式サイト URL からアイコン画像を取得します")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if viewModel.publisherHasIcon(name: publisherName) {
                    Section {
                        Button(role: .destructive) {
                            viewModel.clearPublisherIcon(name: publisherName)
                            previewData = nil
                            dismiss()
                        } label: {
                            Label("現在のアイコンを削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(publisherName)
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let data = previewData {
                            let source = (mode == .url) ? urlInput.trimmingCharacters(in: .whitespaces) : nil
                            viewModel.setPublisherIcon(
                                name: publisherName,
                                imageData: data,
                                sourceURL: source?.isEmpty == true ? nil : source
                            )
                        }
                        dismiss()
                    }
                    .disabled(previewData == nil)
                }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self) else { return }
            let prepared = PublisherIconService.prepareLocalIcon(from: raw)
            await MainActor.run {
                previewData = prepared
                if prepared == nil {
                    errorMessage = "選んだ画像を読み込めませんでした"
                } else {
                    errorMessage = nil
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "写真の読み込みに失敗しました"
            }
        }
    }

    private func fetchFromURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isFetching = true
        errorMessage = nil
        Task {
            do {
                let result = try await PublisherIconService.fetchIcon(for: trimmed)
                await MainActor.run {
                    previewData = result.data
                    isFetching = false
                }
            } catch {
                await MainActor.run {
                    let msg = (error as? PublisherIconError)?.errorDescription
                        ?? "URL からアイコンを取得できませんでした"
                    errorMessage = msg
                    isFetching = false
                }
            }
        }
    }
}
