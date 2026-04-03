import SwiftUI
import PlatformKit

struct CatchUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("browserMode") private var browserMode: String = "external"

    var viewModel: MangaViewModel
    let day: DayOfWeek
    var publisher: String? = nil

    @State private var unreadItems: [MangaEntry] = []
    @State private var currentIndex: Int = 0
    @State private var offset: CGSize = .zero
    @State private var undoStack: [(entry: MangaEntry, action: SwipeAction)] = []
    @State private var completionAnimated = false
    @State private var safariURL: URL?
    @AppStorage("hasSeenCatchUpTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var editingEntry: MangaEntry?
    @State private var reloadCount: Int = 0
    @State private var achievementAnimated = false
    @State private var streakAchievement: Int?
    @State private var milestoneAchievement: Int?

    private enum SwipeAction {
        case read, skip
    }

    private var totalCount: Int { unreadItems.count }
    private var remainingCount: Int { max(totalCount - currentIndex, 0) }
    private var isCompleted: Bool { currentIndex >= totalCount }

    var body: some View {
        NavigationStack {
            VStack {
                if unreadItems.isEmpty {
                    completedView(message: "未読のマンガはありません")
                } else if isCompleted {
                    completedView(message: "すべてチェックしました！")
                } else {
                    cardStackView
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("\(day.displayName)のキャッチアップ")
                            .font(.headline)
                        if let publisher {
                            Text(publisher)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                if !undoStack.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            undoAction()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
        .onAppear {
            if unreadItems.isEmpty {
                unreadItems = filteredUnreadEntries()
            }
            if !hasSeenTutorial && !unreadItems.isEmpty {
                showTutorial = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mangaDataDidChange)) { _ in
            reloadEntries()
        }
        .overlay {
            if showTutorial {
                CatchUpTutorialOverlay(hasSeenTutorial: $hasSeenTutorial, showTutorial: $showTutorial)
            }
        }
        .sheet(item: $editingEntry, onDismiss: {
            editingEntry = nil
            reloadEntries()
            reloadCount += 1
        }) { entry in
            EditEntryView(viewModel: viewModel, entry: entry, showsDeleteButton: false)
        }
        #if canImport(UIKit)
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        #endif
    }

    // MARK: - Card Stack

    private var cardStackView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            HStack {
                Text("\(currentIndex + 1) / \(totalCount)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("残り \(remainingCount) 件")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ProgressView(value: Double(currentIndex), total: Double(totalCount))
                .padding(.horizontal)

            ZStack {
                if currentIndex + 1 < totalCount {
                    CatchUpCardView(entry: unreadItems[currentIndex + 1], editingEntry: $editingEntry, onOpenURL: openMangaURL)
                        .id("\(unreadItems[currentIndex + 1].id)-\(reloadCount)")
                        .scaleEffect(0.95)
                        .opacity(0.5)
                        .allowsHitTesting(false)
                }

                CatchUpCardView(entry: unreadItems[currentIndex], editingEntry: $editingEntry, onOpenURL: openMangaURL)
                    .id("\(unreadItems[currentIndex].id)-\(reloadCount)")
                    .offset(offset)
                    .rotationEffect(.degrees(Double(offset.width) / 20))
                    .overlay {
                        CatchUpSwipeOverlay(offsetWidth: offset.width)
                    }
                    .gesture(dragGesture)
            }
            .padding(.horizontal)

            HStack(spacing: 60) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        offset = CGSize(width: -500, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        performAction(.skip)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44))
                        Text("あとで")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.orange)
                }

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        offset = CGSize(width: 500, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        performAction(.read)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                        Text("既読")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.green)
                }
            }
            .padding(.bottom)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                if value.translation.width > threshold {
                    withAnimation(.spring(duration: 0.3)) {
                        offset = CGSize(width: 500, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        performAction(.read)
                    }
                } else if value.translation.width < -threshold {
                    withAnimation(.spring(duration: 0.3)) {
                        offset = CGSize(width: -500, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        performAction(.skip)
                    }
                } else {
                    withAnimation(.spring(duration: 0.3)) {
                        offset = .zero
                    }
                }
            }
    }

    // MARK: - Actions

    private func performAction(_ action: SwipeAction) {
        guard currentIndex < unreadItems.count else { return }
        let entry = unreadItems[currentIndex]
        undoStack.append((entry: entry, action: action))

        if action == .read {
            viewModel.markAsRead(entry)
        }

        offset = .zero
        currentIndex += 1
    }

    private func filteredUnreadEntries() -> [MangaEntry] {
        let entries = viewModel.unreadEntries(for: day)
        if let publisher {
            return entries.filter { $0.publisher == publisher }
        }
        return entries
    }

    private func reloadEntries() {
        let processedIDs = Set(undoStack.filter { $0.action == .read }.map { $0.entry.id })
        let allUnread = filteredUnreadEntries()

        var neededIDs = Set(unreadItems.prefix(currentIndex).map(\.id))
        neededIDs.formUnion(undoStack.map(\.entry.id))
        let freshEntries = viewModel.findEntries(by: neededIDs)

        var newItems: [MangaEntry] = []

        for i in 0..<currentIndex where i < unreadItems.count {
            let oldEntry = unreadItems[i]
            if let fresh = freshEntries[oldEntry.id] {
                newItems.append(fresh)
            }
        }

        for entry in allUnread where !processedIDs.contains(entry.id) && !newItems.contains(where: { $0.id == entry.id }) {
            newItems.append(entry)
        }

        unreadItems = newItems
        undoStack = undoStack.compactMap { item in
            guard let fresh = freshEntries[item.entry.id] else { return nil }
            return (entry: fresh, action: item.action)
        }
    }

    private func undoAction() {
        guard let last = undoStack.popLast() else { return }

        if last.action == .read {
            viewModel.markAsUnread(last.entry)
        }

        currentIndex -= 1
        offset = .zero
    }

    // MARK: - Completed View

    private static let milestones = [10, 30, 50, 100, 200, 300, 500, 750, 1000, 2000, 3000, 5000, 10000]

    private var sessionReadCount: Int {
        undoStack.filter { $0.action == .read }.count
    }

    private func checkStreakAchievement() -> Int? {
        guard sessionReadCount > 0 else { return nil }
        let streak = viewModel.stats.currentStreak()
        guard streak >= 2 else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let lastShown = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastStreakShownDate) as? Date
        if lastShown == today { return nil }
        UserDefaults.standard.set(today, forKey: UserDefaultsKeys.lastStreakShownDate)
        return streak
    }

    private func checkMilestoneAchievement() -> Int? {
        guard sessionReadCount > 0 else { return nil }
        let total = viewModel.stats.totalReadCount()
        let beforeSession = total - sessionReadCount
        let shownMilestones = UserDefaults.standard.array(forKey: UserDefaultsKeys.shownMilestones) as? [Int] ?? []
        for milestone in Self.milestones {
            if beforeSession < milestone && total >= milestone && !shownMilestones.contains(milestone) {
                var updated = shownMilestones
                updated.append(milestone)
                UserDefaults.standard.set(updated, forKey: UserDefaultsKeys.shownMilestones)
                return milestone
            }
        }
        return nil
    }

    private func completedView(message: String) -> some View {
        CatchUpCompletedView(
            message: message,
            remainingUnread: filteredUnreadEntries().count,
            streakAchievement: $streakAchievement,
            milestoneAchievement: $milestoneAchievement,
            completionAnimated: $completionAnimated,
            achievementAnimated: $achievementAnimated,
            checkStreak: checkStreakAchievement,
            checkMilestone: checkMilestoneAchievement
        ) {
            completionAnimated = false
            achievementAnimated = false
            streakAchievement = nil
            milestoneAchievement = nil
            unreadItems = filteredUnreadEntries()
            currentIndex = 0
            undoStack = []
        }
    }

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(urlString)
    }
}
