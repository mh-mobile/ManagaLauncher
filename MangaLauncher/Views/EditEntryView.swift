import SwiftUI
import SwiftData
import PhotosUI

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss

    var viewModel: MangaViewModel
    var entry: MangaEntry?

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selectedDay: DayOfWeek = .monday
    @State private var selectedColor: String = "blue"
    @State private var publisher: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

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

    private var isEditing: Bool { entry != nil }

    private var isValidURL: Bool {
        guard let url = URL(string: url) else { return false }
        return url.scheme != nil && !url.scheme!.isEmpty
    }

    init(viewModel: MangaViewModel, entry: MangaEntry) {
        self.viewModel = viewModel
        self.entry = entry
    }

    init(viewModel: MangaViewModel, day: DayOfWeek) {
        self.viewModel = viewModel
        self.entry = nil
        _selectedDay = State(initialValue: day)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $name)
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("URL", text: $url)
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                    if !url.isEmpty && !isValidURL {
                        Text("有効なURLを入力してください（例: https://... または shortcuts://...）")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    NavigationLink {
                        PublisherPickerView(publisher: $publisher, viewModel: viewModel)
                    } label: {
                        HStack {
                            Text("掲載誌")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(publisher.isEmpty ? "未設定" : publisher)
                                .foregroundStyle(publisher.isEmpty ? .tertiary : .secondary)
                        }
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
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("画像を変更", systemImage: "photo")
                            }
                        }
                        Button(role: .destructive) {
                            self.imageData = nil
                            selectedPhotoItem = nil
                        } label: {
                            Label("画像を削除", systemImage: "trash")
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("画像を選択", systemImage: "photo")
                        }
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            if let jpeg = downsizedJPEGData(data, maxDimension: 600) {
                                imageData = jpeg
                            }
                        }
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
                                    selectedDay == day
                                        ? .white
                                        : .primary
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

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let entry {
                                viewModel.deleteEntry(entry)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("削除")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "編集" : "新規登録")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveEntry()
                        dismiss()
                    }
                    .disabled(name.isEmpty || url.isEmpty || !isValidURL)
                }
            }
            .onAppear {
                if let entry {
                    name = entry.name
                    url = entry.url
                    selectedColor = entry.iconColor
                    selectedDay = entry.dayOfWeek
                    publisher = entry.publisher
                    imageData = entry.imageData
                }
            }
        }
    }

    private func saveEntry() {
        if let entry {
            viewModel.updateEntry(entry, name: name, url: url, dayOfWeek: selectedDay, iconColor: selectedColor, publisher: publisher, imageData: imageData)
        } else {
            viewModel.addEntry(name: name, url: url, days: [selectedDay], iconColor: selectedColor, publisher: publisher, imageData: imageData)
        }
    }
}

#Preview("New Entry") {
    let container = try! ModelContainer(for: MangaEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let viewModel = MangaViewModel(modelContext: container.mainContext)
    EditEntryView(viewModel: viewModel, day: .monday)
}

#Preview("Edit Entry") {
    let container = try! ModelContainer(for: MangaEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let viewModel = MangaViewModel(modelContext: container.mainContext)
    let entry = MangaEntry(name: "ジャンプ+", url: "https://shonenjumpplus.com", dayOfWeek: .monday, iconColor: "red")
    EditEntryView(viewModel: viewModel, entry: entry)
}
