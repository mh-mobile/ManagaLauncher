import SwiftUI
import UniformTypeIdentifiers

struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @State private var status: ShareStatus = .loading
    @State private var pendingData: PendingShareData?

    enum ShareStatus {
        case loading
        case result
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch status {
                case .loading:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("解析中...")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .result:
                    if let data = pendingData {
                        VStack(alignment: .leading, spacing: 12) {
                            if let imageData = data.imageData, let image = imageData.toSwiftUIImage() {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(maxWidth: .infinity)
                            }
                            LabeledContent("タイトル") { Text(data.name) }
                            LabeledContent("URL") { Text(data.url).lineLimit(1) }
                            LabeledContent("掲載誌") { Text(data.publisher.isEmpty ? "未設定" : data.publisher) }
                            Spacer()
                        }
                        .padding()
                    }
                case .error(let message):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("マンガ曜日に追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        extensionContext?.completeRequest(returningItems: nil)
                    }
                }
                if case .result = status {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("追加") {
                            openMainApp()
                        }
                    }
                }
            }
        }
        .task {
            await processSharedContent()
        }
    }

    private func processSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            status = .error("共有データを取得できませんでした")
            return
        }

        var sharedURL = ""
        var sharedText = ""

        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        sharedURL = url.absoluteString
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                        sharedText = text
                    }
                }
            }
        }

        if sharedURL.isEmpty && !sharedText.isEmpty {
            // Text might contain a URL
            if let url = URL(string: sharedText), url.scheme != nil {
                sharedURL = sharedText
            }
        }

        guard !sharedURL.isEmpty else {
            status = .error("URLが見つかりませんでした")
            return
        }

        // Extract manga info using Foundation Model or fallback
        let info = await MangaExtractor.extract(sharedText: sharedText, sharedURL: sharedURL)
            ?? MangaExtractor.extractFallback(sharedText: sharedText, sharedURL: sharedURL)

        // Fetch OGP image
        let imageData = await OGPImageFetcher.fetchOGPImageData(from: info.url)

        let pending = PendingShareData(
            name: info.title,
            url: info.url,
            publisher: info.publisher,
            imageData: imageData
        )

        pendingData = pending

        do {
            try pending.save()
            status = .result
        } catch {
            status = .error("データの保存に失敗しました")
        }
    }

    private func openMainApp() {
        guard let data = pendingData else { return }
        let urlString = "mangalauncher://add?pending=\(data.id.uuidString)"
        guard let url = URL(string: urlString) else { return }

        // Open main app via responder chain URL opening trick since UIApplication.shared is not available in extensions
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = extensionContext as? UIResponder
        // Walk the responder chain to find UIApplication
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
