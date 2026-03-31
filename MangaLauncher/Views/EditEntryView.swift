import SwiftUI
import SwiftData
import PhotosUI
import PlatformKit
import OGPKit
#if canImport(UIKit)
import Mantis
#endif

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
    @State private var updateIntervalWeeks: Int = 1
    @State private var isCustomInterval = false
    @State private var nextUpdateDate: Date = Date()
    @State private var isLoadingImage = false
    @State private var ogpFetchFailed = false
    @State private var showingCropView = false
    @State private var didLoadEntry = false
    @State private var isOnHiatus = false

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

    private static let presetIntervals = [1, 2, 3, 4, 8]

    private var actualIntervalWeeks: Int {
        isCustomInterval && updateIntervalWeeks == -1 ? 5 : max(updateIntervalWeeks, 1)
    }

    private var pickerValue: Binding<Int> {
        Binding(
            get: { isCustomInterval ? -1 : (Self.presetIntervals.contains(updateIntervalWeeks) ? updateIntervalWeeks : -1) },
            set: { newValue in
                if newValue == -1 {
                    isCustomInterval = true
                    if Self.presetIntervals.contains(updateIntervalWeeks) {
                        updateIntervalWeeks = 5
                    }
                } else {
                    isCustomInterval = false
                    updateIntervalWeeks = newValue
                }
            }
        )
    }

    private var nextUpdateCandidates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) - 1
        let target = selectedDay.rawValue
        let daysToNext = (target - todayWeekday + 7) % 7
        let firstDate = daysToNext == 0 ? today : calendar.date(byAdding: .day, value: daysToNext, to: today)!
        return (0..<8).map { i in
            calendar.date(byAdding: .day, value: i * 7, to: firstDate)!
        }
    }

    private func nextOccurrence(of day: DayOfWeek) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) - 1 // 0=Sun
        let target = day.rawValue
        let daysAhead = (target - todayWeekday + 7) % 7
        let next = daysAhead == 0 ? 7 : daysAhead // if today, go to next week
        return calendar.date(byAdding: .day, value: next, to: today)!
    }

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

    init(viewModel: MangaViewModel, prefilledName: String, prefilledURL: String, prefilledDay: DayOfWeek, prefilledPublisher: String, prefilledColor: String, prefilledImageData: Data? = nil) {
        self.viewModel = viewModel
        self.entry = nil
        _name = State(initialValue: prefilledName)
        _url = State(initialValue: prefilledURL)
        _selectedDay = State(initialValue: prefilledDay)
        _publisher = State(initialValue: prefilledPublisher)
        _selectedColor = State(initialValue: prefilledColor)
        _imageData = State(initialValue: prefilledImageData)
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
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #if canImport(UIKit)
                        Button {
                            showingCropView = true
                        } label: {
                            Label("画像を編集", systemImage: "crop")
                        }
                        #endif
                        Button(role: .destructive) {
                            self.imageData = nil
                            selectedPhotoItem = nil
                        } label: {
                            Label("画像を削除", systemImage: "trash")
                        }
                    } else if isLoadingImage {
                        HStack {
                            ProgressView()
                            Text("画像を取得中...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("カメラロールから選択", systemImage: "photo")
                        }
                        #if canImport(UIKit)
                        PasteButton(payloadType: PasteImage.self) { items in
                            guard let item = items.first,
                                  let jpeg = downsizedJPEGData(item.data, maxDimension: 600) else { return }
                            imageData = jpeg
                        }
                        #endif
                        if isValidURL {
                            Button {
                                fetchOGPImage()
                            } label: {
                                Label("URLからサムネイル画像を取得", systemImage: "link")
                            }
                        }
                        if ogpFetchFailed {
                            Text("サムネイル画像を取得できませんでした")
                                .font(.caption)
                                .foregroundStyle(.red)
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
                        ForEach(DayOfWeek.orderedDays) { day in
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
                                    // nextUpdateCandidatesはselectedDayに依存するので
                                    // 先に更新してから候補の先頭を設定
                                    DispatchQueue.main.async {
                                        if let first = nextUpdateCandidates.first {
                                            nextUpdateDate = first
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle("休載中", isOn: $isOnHiatus)
                }

                Section("更新頻度") {
                    Picker("頻度", selection: pickerValue) {
                        Text("毎週").tag(1)
                        Text("隔週").tag(2)
                        Text("3週ごと").tag(3)
                        Text("月1回").tag(4)
                        Text("2ヶ月ごと").tag(8)
                        Text("カスタム").tag(-1)
                    }
                    if isCustomInterval {
                        Stepper("\(updateIntervalWeeks)週ごと", value: $updateIntervalWeeks, in: 1...52)
                    }
                    if actualIntervalWeeks >= 2 {
                        Picker("次の更新日", selection: $nextUpdateDate) {
                            ForEach(nextUpdateCandidates, id: \.self) { date in
                                Text(date.formatted(.dateTime.month().day().weekday()))
                                    .tag(date)
                            }
                        }
                    }
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
                if let entry, !didLoadEntry {
                    name = entry.name
                    url = entry.url
                    selectedColor = entry.iconColor
                    selectedDay = entry.dayOfWeek
                    publisher = entry.publisher
                    imageData = entry.imageData
                    updateIntervalWeeks = entry.updateIntervalWeeks
                    isCustomInterval = !Self.presetIntervals.contains(entry.updateIntervalWeeks)
                    let candidates = nextUpdateCandidates
                    if let saved = entry.nextExpectedUpdate, candidates.contains(saved) {
                        nextUpdateDate = saved
                    } else {
                        nextUpdateDate = candidates.first ?? nextOccurrence(of: entry.dayOfWeek)
                    }
                    isOnHiatus = entry.isOnHiatus
                    didLoadEntry = true
                }
            }
            #if canImport(UIKit)
            .fullScreenCover(isPresented: $showingCropView) {
                if let imageData {
                    ImageCropView(
                        imageData: imageData,
                        onCropped: { croppedData in
                            self.imageData = croppedData
                            showingCropView = false
                        },
                        onCancel: {
                            showingCropView = false
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            #endif
        }
    }

    private func fetchOGPImage() {
        guard isValidURL else { return }
        isLoadingImage = true
        ogpFetchFailed = false
        Task {
            let ogp = await OGPFetcher.fetch(from: url)
            if let ogpImageData = ogp.imageData {
                imageData = ogpImageData
            } else {
                ogpFetchFailed = true
            }
            isLoadingImage = false
        }
    }

    private func saveEntry() {
        let interval = actualIntervalWeeks
        if let entry {
            viewModel.updateEntry(entry, name: name, url: url, dayOfWeek: selectedDay, iconColor: selectedColor, publisher: publisher, imageData: imageData, updateIntervalWeeks: interval, nextExpectedUpdate: interval >= 2 ? nextUpdateDate : nil)
            entry.isOnHiatus = isOnHiatus
        } else {
            viewModel.addEntry(name: name, url: url, days: [selectedDay], iconColor: selectedColor, publisher: publisher, imageData: imageData, updateIntervalWeeks: interval, nextExpectedUpdate: interval >= 2 ? nextUpdateDate : nil)
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
