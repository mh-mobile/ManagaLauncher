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
    var showsDeleteButton: Bool = true

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
    @State private var publicationStatus: PublicationStatus = .active
    @State private var readingState: ReadingState = .following
    @State private var isOneShot = false
    @State private var memo: String = ""
    @State private var currentEpisode: Int?
    @State private var episodeText: String = ""
    @State private var episodeLabel: String = ""
    @State private var markAsReadOnSave: Bool = false

    private var theme: ThemeStyle { ThemeManager.shared.style }

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

    private static let allowedSchemes: Set<String> = ["https", "http"]

    private var isValidURL: Bool {
        guard let url = URL(string: url),
              let scheme = url.scheme?.lowercased() else { return false }
        return Self.allowedSchemes.contains(scheme)
    }

    init(viewModel: MangaViewModel, entry: MangaEntry, showsDeleteButton: Bool = true) {
        self.viewModel = viewModel
        self.entry = entry
        self.showsDeleteButton = showsDeleteButton
    }

    init(viewModel: MangaViewModel, day: DayOfWeek) {
        self.viewModel = viewModel
        self.entry = nil
        _selectedDay = State(initialValue: day)
    }

    init(viewModel: MangaViewModel, prefilledName: String, prefilledURL: String, prefilledDay: DayOfWeek, prefilledPublisher: String, prefilledColor: String, prefilledImageData: Data? = nil, prefilledIsOneShot: Bool = false) {
        self.viewModel = viewModel
        self.entry = nil
        _name = State(initialValue: prefilledName)
        _url = State(initialValue: prefilledURL)
        _selectedDay = State(initialValue: prefilledDay)
        _publisher = State(initialValue: prefilledPublisher)
        _selectedColor = State(initialValue: prefilledColor)
        _imageData = State(initialValue: prefilledImageData)
        _isOneShot = State(initialValue: prefilledIsOneShot)
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
                        Text("有効なURLを入力してください（例: https://...）")
                            .font(theme.captionFont)
                            .foregroundStyle(theme.error)
                    }
                    NavigationLink {
                        PublisherPickerView(publisher: $publisher, viewModel: viewModel)
                    } label: {
                        HStack {
                            Text("掲載誌")
                                .foregroundStyle(theme.onSurface)
                            Spacer()
                            Text(publisher.isEmpty ? "未設定" : publisher)
                                .foregroundStyle(publisher.isEmpty ? theme.onSurfaceVariant.opacity(0.5) : theme.onSurfaceVariant)
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
                                .font(theme.subheadlineFont)
                                .frame(width: 36, height: 36)
                                .background(
                                    selectedDay == day
                                        ? theme.primary
                                        : theme.surfaceContainerHighest
                                )
                                .foregroundStyle(
                                    selectedDay == day
                                        ? theme.onPrimary
                                        : theme.onSurface
                                )
                                .clipShape(theme.chipShape)
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

                EditEntryStatusSection(
                    isOneShot: $isOneShot,
                    publicationStatus: $publicationStatus,
                    readingState: $readingState
                )

                if !isOneShot && publicationStatus == .active && readingState == .following {
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
                        if actualIntervalWeeks >= 1 {
                            Picker("次の更新日", selection: $nextUpdateDate) {
                                ForEach(nextUpdateCandidates, id: \.self) { date in
                                    Text(date.formatted(.dateTime.month().day().weekday()))
                                        .tag(date)
                                }
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text("話数")
                        Spacer()
                        TextField("未設定", text: $episodeText)
                            #if os(iOS) || os(visionOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .onChange(of: episodeText) { _, newValue in
                                if newValue.isEmpty {
                                    currentEpisode = nil
                                } else if let val = Int(newValue), val > 0 {
                                    currentEpisode = val
                                }
                            }
                        if currentEpisode != nil {
                            Button {
                                currentEpisode = nil
                                episodeText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Text("ラベル")
                        Spacer()
                        TextField("おまけ、1.5話 など", text: $episodeLabel)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS) || os(visionOS)
                            .textInputAutocapitalization(.none)
                            #endif
                    }
                    Toggle("保存時に既読にする", isOn: $markAsReadOnSave)
                        .onChange(of: markAsReadOnSave) { _, isOn in
                            if isOn { episodeLabel = "" }
                        }
                } header: {
                    Text("話数")
                } footer: {
                    Text("読んだ話数を記録します。「保存時に既読にする」をオンにすると、保存と同時に読書記録が作成されます。")
                }

                Section {
                    TextField("メモ（あらすじ・キャラ相関図など）", text: $memo, axis: .vertical)
                        .lineLimit(3...10)
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.none)
                        #endif
                } header: {
                    Text("メモ")
                } footer: {
                    Text("作品ごとに 1 つの長文メモを保存できます。コメントとは別物です。")
                }

                Section {
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
                    if let label = ColorLabelStore.shared.label(for: selectedColor) {
                        HStack {
                            Text("ラベル")
                                .foregroundStyle(theme.onSurfaceVariant)
                            Spacer()
                            Text(label)
                                .foregroundStyle(theme.onSurface)
                        }
                    }
                } header: {
                    Text("アイコンカラー")
                }

                if isEditing && showsDeleteButton {
                    Section {
                        Button(role: .destructive) {
                            if let entry {
                                viewModel.queueDelete(entry)
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
            .themedNavigationStyle()
            .navigationTitle(isEditing ? "編集" : "新規登録")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .if(theme.forceDarkMode) { view in
                        view.foregroundStyle(theme.onSurfaceVariant)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveEntry()
                        dismiss()
                    }
                    .disabled(name.isEmpty || url.isEmpty || !isValidURL)
                    .if(theme.forceDarkMode) { view in
                        view.foregroundStyle(theme.primary)
                    }
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
                    publicationStatus = entry.publicationStatus
                    readingState = entry.readingState
                    isOneShot = entry.isOneShot
                    memo = entry.memo
                    currentEpisode = entry.currentEpisode
                    episodeText = entry.currentEpisode.map { String($0) } ?? ""
                    episodeLabel = entry.episodeLabel ?? ""
                    didLoadEntry = true
                } else if entry == nil, !didLoadEntry {
                    nextUpdateDate = nextUpdateCandidates.first ?? nextOccurrence(of: selectedDay)
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
        let labelToSave = episodeLabel.isEmpty ? nil : episodeLabel
        if let entry {
            viewModel.updateEntry(
                entry,
                name: name,
                url: url,
                dayOfWeek: selectedDay,
                iconColor: selectedColor,
                publisher: publisher,
                imageData: imageData,
                updateIntervalWeeks: interval,
                nextExpectedUpdate: nextUpdateDate,
                isOneShot: isOneShot,
                publicationStatus: publicationStatus,
                readingState: readingState,
                memo: memo,
                currentEpisode: currentEpisode,
                episodeLabel: labelToSave,
                markAsReadOnSave: markAsReadOnSave
            )
        } else {
            viewModel.addEntry(
                name: name,
                url: url,
                days: [selectedDay],
                iconColor: selectedColor,
                publisher: publisher,
                imageData: imageData,
                updateIntervalWeeks: isOneShot ? 1 : interval,
                nextExpectedUpdate: isOneShot ? nil : nextUpdateDate,
                publicationStatus: isOneShot ? .active : publicationStatus,
                readingState: readingState,
                isOneShot: isOneShot,
                memo: memo,
                currentEpisode: currentEpisode,
                episodeLabel: labelToSave
            )
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
