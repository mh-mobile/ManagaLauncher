import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @State private var isLoading = true
    @State private var aiExtracted = false
    @State private var name = ""
    @State private var url = ""
    @State private var publisher = ""
    @State private var selectedDay: DayOfWeek = .today
    @State private var selectedColor = "blue"
    @State private var imageData: Data?
    @State private var saveError: String?

    private let colorOptions: [(name: String, color: Color)] = [
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink),
        ("teal", .teal),
    ]

    private var isValidURL: Bool {
        guard let url = URL(string: url) else { return false }
        return url.scheme != nil && !url.scheme!.isEmpty
    }

    var body: some View {
        NavigationStack {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("読み込み中...")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("マンガ曜日に追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            extensionContext?.completeRequest(returningItems: nil)
                        }
                    }
                }
            } else {
                Form {
                    Section {
                        TextField("名前", text: $name)
                            .textInputAutocapitalization(.never)
                        TextField("URL", text: $url)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                        if !url.isEmpty && !isValidURL {
                            Text("有効なURLを入力してください")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        TextField("掲載誌", text: $publisher)
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text("基本情報")
                    } footer: {
                        if aiExtracted {
                            Text("名前はAIによる推定です。内容を確認してください。")
                        }
                    }

                    Section("画像") {
                        if let imageData, let image = imageData.toSwiftUIImage() {
                            HStack {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Spacer()
                                Button(role: .destructive) {
                                    self.imageData = nil
                                } label: {
                                    Label("画像を削除", systemImage: "trash")
                                }
                            }
                        } else {
                            Text("OGP画像が取得できませんでした")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("曜日") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(DayOfWeek.orderedCases) { day in
                                Text(day.shortName)
                                    .font(.subheadline.bold())
                                    .frame(width: 36, height: 36)
                                    .background(
                                        selectedDay == day
                                            ? Color.accentColor
                                            : Color.platformGray5
                                    )
                                    .foregroundStyle(
                                        selectedDay == day ? .white : .primary
                                    )
                                    .clipShape(Circle())
                                    .onTapGesture {
                                        selectedDay = day
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("アイコンカラー") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                            ForEach(colorOptions, id: \.name) { option in
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColor == option.name {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedColor = option.name
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if let saveError {
                        Section {
                            Text(saveError)
                                .foregroundStyle(.red)
                        }
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
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            saveEntry()
                        }
                        .disabled(name.isEmpty || url.isEmpty || !isValidURL)
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
            isLoading = false
            return
        }

        var sharedURL = ""
        var sharedText = ""

        for item in items {
            // attributedContentText contains the full share text
            if let attrText = item.attributedContentText?.string, !attrText.isEmpty {
                sharedText = attrText
            }

            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let urlItem = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        sharedURL = urlItem.absoluteString
                    }
                }
                if sharedText.isEmpty, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                        sharedText = text
                    }
                }
            }
        }

        // Extract URL from text if not found as URL type
        if sharedURL.isEmpty && !sharedText.isEmpty {
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                let range = NSRange(sharedText.startIndex..., in: sharedText)
                let matches = detector.matches(in: sharedText, range: range)
                if let firstURL = matches.first?.url {
                    sharedURL = firstURL.absoluteString
                }
            }
        }

        // If shared URL is an X/Twitter post, fetch the page and extract external URLs
        let xDomains = ["x.com", "twitter.com"]
        let isXPost = URL(string: sharedURL).flatMap { url in
            xDomains.contains(where: { url.host?.hasSuffix($0) == true })
        } ?? false

        if isXPost {
            let xResult = await extractFromXPost(sharedURL)
            if let extractedURL = xResult.url {
                sharedURL = extractedURL
            }
            if let tweetText = xResult.text, !tweetText.isEmpty {
                sharedText = tweetText
            }
        } else if !sharedURL.isEmpty {
            sharedURL = await URLResolver.resolveAll(sharedURL)
        }

        url = sharedURL

        // Fetch OGP data (image, site_name)
        if !sharedURL.isEmpty {
            let ogp = await OGPFetcher.fetch(from: sharedURL)
            imageData = ogp.imageData
            if let siteName = ogp.siteName, !siteName.isEmpty {
                publisher = siteName
            }
        }

        // Extract manga title using Foundation Model
        let result = await MangaExtractor.extract(sharedText: sharedText, sharedURL: sharedURL)

        // Only use AI results if title and publisher are different
        if result.method == "ai" && !result.title.isEmpty && !result.publisher.isEmpty && result.title != result.publisher {
            name = result.title
            // AI publisher overrides OGP site_name only if publisher is still empty
            if publisher.isEmpty {
                publisher = result.publisher
            }
            aiExtracted = true
        }

        isLoading = false
    }

    private func extractFromXPost(_ xURL: String) async -> (url: String?, text: String?) {
        // Use Twitter oEmbed API to get tweet HTML with links
        guard let encoded = xURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let oembedURL = URL(string: "https://publish.twitter.com/oembed?url=\(encoded)") else { return (nil, nil) }

        guard let (data, _) = try? await URLSession.shared.data(from: oembedURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let html = json["html"] as? String else { return (nil, nil) }

        // Extract plain text from oEmbed HTML (strip tags)
        let tweetText = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract t.co links from the oEmbed HTML
        let pattern = "https?://t\\.co/[A-Za-z0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (nil, tweetText) }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        var seen = Set<String>()
        for match in matches {
            guard let matchRange = Range(match.range, in: html) else { continue }
            let tcoURL = String(html[matchRange])
            guard !seen.contains(tcoURL) else { continue }
            seen.insert(tcoURL)

            let resolved = await URLResolver.resolveAll(tcoURL)
            let resolvedHost = URL(string: resolved)?.host ?? ""

            let xDomains = ["x.com", "twitter.com", "t.co"]
            if !xDomains.contains(where: { resolvedHost.hasSuffix($0) }) {
                return (resolved, tweetText)
            }
        }

        return (nil, tweetText)
    }

    private func saveEntry() {
        do {
            let container = try SharedModelContainer.create()
            let context = ModelContext(container)

            let dayRawValue = selectedDay.rawValue
            let descriptor = FetchDescriptor<MangaEntry>(
                predicate: #Predicate { $0.dayOfWeekRawValue == dayRawValue },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            let existingEntries = (try? context.fetch(descriptor)) ?? []
            let maxOrder = existingEntries.map(\.sortOrder).max() ?? -1

            let entry = MangaEntry(
                name: name,
                url: url,
                dayOfWeek: selectedDay,
                sortOrder: maxOrder + 1,
                iconColor: selectedColor,
                publisher: publisher,
                imageData: imageData
            )
            context.insert(entry)
            try context.save()

            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            saveError = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
