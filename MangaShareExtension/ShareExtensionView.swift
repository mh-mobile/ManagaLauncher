import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @State private var isLoading = true
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
                    Section("基本情報") {
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
                            ForEach(DayOfWeek.allCases) { day in
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
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let urlItem = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        sharedURL = urlItem.absoluteString
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
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

        // Set URL
        url = sharedURL

        // Fetch OGP image
        if !url.isEmpty {
            imageData = await OGPImageFetcher.fetchOGPImageData(from: url)
        }

        isLoading = false
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
