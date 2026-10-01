import SwiftUI
import PlatformKit

struct CatchUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"

    var viewModel: MangaViewModel
    /// 対象曜日。nil の場合は全曜日横断の未読をまとめてキャッチアップする（Library 経由の起動）。
    let day: DayOfWeek?
    var publisher: String? = nil

    @State private var session = CatchUpSession()
    @State private var offset: CGSize = .zero
    @State private var completionAnimated = false
    @State private var safariURL: URL?
    @State private var quickViewContext: BrowserContext?
    @AppStorage(UserDefaultsKeys.hasSeenCatchUpTutorial) private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var editingEntry: MangaEntry?
    @State private var reloadCount: Int = 0
    @State private var achievementAnimated = false
    @State private var streakAchievement: Int?
    @State private var milestoneAchievement: Int?
    @State private var backgroundGradient: ImageColorExtractor.GradientColors?
    @State private var gradientTask: Task<Void, Never>?
    @State private var showMarkAllReadAlert = false

    private var theme: ThemeStyle { ThemeManager.shared.style }
    private var hasGradient: Bool { backgroundGradient != nil }

    private typealias SwipeAction = CatchUpSession.Action

    private var totalCount: Int { session.items.count }
    private var remainingCount: Int { max(totalCount - session.currentIndex, 0) }
    private var isCompleted: Bool { session.currentIndex >= totalCount }

    var body: some View {
        NavigationStack {
            VStack {
                if session.items.isEmpty {
                    completedView(message: "未読のマンガはありません")
                } else if isCompleted {
                    completedView(message: "すべてチェックしました！")
                } else {
                    cardStackView
                }
            }
            .background {
                if let gradient = backgroundGradient {
                    LinearGradient(
                        colors: [gradient.top, gradient.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: backgroundGradient)
                } else if theme.usesCustomSurface {
                    theme.surface.ignoresSafeArea()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(day.map { "\($0.displayName)のキャッチアップ" } ?? "未読のキャッチアップ")
                            .font(theme.headlineFont)
                            .foregroundStyle(hasGradient ? .white : theme.onSurface)
                        if let publisher {
                            Text(publisher)
                                .font(theme.captionFont)
                                .foregroundStyle(hasGradient ? .white.opacity(0.7) : theme.onSurfaceVariant)
                        }
                    }
                }
            }
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(hasGradient ? .white : (theme.forceDarkMode ? theme.primary : Color.accentColor))
                }
                if !session.undoStack.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            undoAction()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .accessibilityLabel("元に戻す")
                        .disabled(session.isBusy)
                    }
                }
                if !isCompleted && !session.items.isEmpty && remainingCount >= 2 {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showMarkAllReadAlert = true
                        } label: {
                            Image(systemName: "checkmark.circle")
                        }
                        .accessibilityLabel("残りを全部既読にする")
                        .disabled(session.isBusy)
                    }
                }
            }
        }
        .onAppear {
            if session.items.isEmpty {
                session.items = filteredUnreadEntries()
            }
            if !hasSeenTutorial && !session.items.isEmpty {
                showTutorial = true
            }
            updateBackgroundGradient()
        }
        .onChange(of: session.currentIndex) { _, newIndex in
            if newIndex < session.items.count {
                updateBackgroundGradient()
            }
        }
        .onMangaDataChange {
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
            SafariView(url: url).ignoresSafeArea()
        }
        .overlay {
            if let ctx = quickViewContext {
                QuickViewBrowserScreen(context: ctx) {
                    quickViewContext = nil
                }
                .ignoresSafeArea()
            }
        }
        #endif
        .alert("残りを全部既読にする", isPresented: $showMarkAllReadAlert) {
            Button("全部既読", role: .destructive) {
                markAllRemainingAsRead()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("残り \(remainingCount) 件を既読にします。この操作は「元に戻す」で取り消せます。")
        }
        .gesture(dismissDragGesture, including: isCompleted || session.items.isEmpty ? .all : .subviews)
        .preferredColorScheme(hasGradient ? .dark : theme.resolvedColorScheme(system: systemColorScheme))
    }

    // MARK: - Card Stack

    private var cardStackView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            HStack {
                Text("\(session.currentIndex + 1) / \(totalCount)")
                    .font(theme.subheadlineFont)
                    .foregroundStyle(hasGradient ? .white : theme.onSurfaceVariant)
                Spacer()
                Text("残り \(remainingCount) 件")
                    .font(theme.subheadlineFont)
                    .foregroundStyle(hasGradient ? .white : theme.onSurfaceVariant)
            }
            .shadow(color: hasGradient ? .black.opacity(0.5) : .clear, radius: 2, y: 1)
            .padding(.horizontal)

            ProgressView(value: Double(session.currentIndex), total: Double(totalCount))
                .if(theme.forceDarkMode) { view in
                    view.tint(theme.primary)
                }
                .padding(.horizontal)

            ZStack {
                if session.currentIndex + 1 < totalCount {
                    CatchUpCardView(entry: session.items[session.currentIndex + 1], viewModel: viewModel, editingEntry: $editingEntry, onOpenURL: openMangaURL, hasGradientBackground: hasGradient)
                        .id("\(session.items[session.currentIndex + 1].id)-\(reloadCount)")
                        .scaleEffect(0.95)
                        .opacity(0.5)
                        .allowsHitTesting(false)
                }

                CatchUpCardView(entry: session.items[session.currentIndex], viewModel: viewModel, editingEntry: $editingEntry, onOpenURL: openMangaURL, hasGradientBackground: hasGradient)
                    .id("\(session.items[session.currentIndex].id)-\(reloadCount)")
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
                    swipe(.skip, to: CGSize(width: -500, height: 0))
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(theme.forceDarkMode ? .system(size: 44, weight: .bold) : .system(size: 44))
                        Text("あとで")
                            .font(theme.forceDarkMode ? .system(size: 12, weight: .black) : .caption.bold())
                    }
                    .foregroundStyle(theme.catchUpSkipColor)
                }

                Button {
                    swipe(.read, to: CGSize(width: 500, height: 0))
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(theme.forceDarkMode ? .system(size: 44, weight: .bold) : .system(size: 44))
                        Text("既読")
                            .font(theme.forceDarkMode ? .system(size: 12, weight: .black) : .caption.bold())
                    }
                    .foregroundStyle(theme.catchUpReadColor)
                }
            }
            .padding(.bottom)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Dismiss Drag Gesture

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                if value.translation.height > 100 && value.translation.height > abs(value.translation.width) {
                    dismiss()
                }
            }
    }

    // MARK: - Card Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !session.isBusy else { return }
                offset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                if value.translation.width > threshold {
                    swipe(.read, to: CGSize(width: 500, height: value.translation.height))
                } else if value.translation.width < -threshold {
                    swipe(.skip, to: CGSize(width: -500, height: value.translation.height))
                } else {
                    withAnimation(.spring(duration: 0.3)) {
                        offset = .zero
                    }
                }
            }
    }

    // MARK: - Actions

    /// スワイプ/ボタンの確定。カードを飛ばすアニメーション後に遅延して確定するので、対象は
    /// 操作時点で予約し、確定待ちの間は次の操作を受け付けない (連打や undo で別の作品が既読になるのを防ぐ)。
    private func swipe(_ action: SwipeAction, to target: CGSize) {
        guard session.beginSwipe() else { return }
        withAnimation(.spring(duration: 0.3)) {
            offset = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.swipeCompletion) {
            if let entry = session.completeSwipe(action) {
                viewModel.markAsRead(entry)
            }
            offset = .zero
        }
    }

    private func filteredUnreadEntries() -> [MangaEntry] {
        let entries = day.map { viewModel.unreadEntries(for: $0) } ?? viewModel.allUnreadEntries()
        if let publisher {
            return entries.filter { $0.publisher == publisher }
        }
        return entries
    }

    private func reloadEntries() {
        let processedIDs = Set(session.undoStack.filter { $0.action == .read }.map { $0.entry.id })
        let allUnread = filteredUnreadEntries()

        var neededIDs = Set(session.items.prefix(session.currentIndex).map(\.id))
        neededIDs.formUnion(session.undoStack.map(\.entry.id))
        let freshEntries = viewModel.findEntries(by: neededIDs)

        var newItems: [MangaEntry] = []

        for i in 0..<session.currentIndex where i < session.items.count {
            let oldEntry = session.items[i]
            if let fresh = freshEntries[oldEntry.id] {
                newItems.append(fresh)
            }
        }

        for entry in allUnread where !processedIDs.contains(entry.id) && !newItems.contains(where: { $0.id == entry.id }) {
            newItems.append(entry)
        }

        session.items = newItems
        // リロード後に session.currentIndex が範囲外にならないよう検証
        if session.currentIndex > newItems.count {
            session.currentIndex = newItems.count
        }
        session.undoStack = session.undoStack.compactMap { item in
            guard let fresh = freshEntries[item.entry.id] else { return nil }
            return (entry: fresh, action: item.action)
        }
    }

    private func undoAction() {
        guard !session.isBusy, let last = session.undoStack.popLast() else { return }

        if last.action == .read {
            viewModel.markAsUnread(last.entry)
        }

        session.currentIndex -= 1
        offset = .zero
    }

    /// 残りの未読エントリをすべて既読にする。
    /// 各エントリを session.undoStack に積むので、完了後に undo で個別に戻せる。
    /// バッチ版 `markEntriesAsRead` を使い、save() を1回にまとめる。
    private func markAllRemainingAsRead() {
        guard !session.isBusy, session.currentIndex < session.items.count else { return }
        let remaining = Array(session.items[session.currentIndex...])
        for entry in remaining {
            session.undoStack.append((entry: entry, action: .read))
        }
        viewModel.markEntriesAsRead(remaining)
        offset = .zero
        session.currentIndex = session.items.count
    }

    // MARK: - Completed View

    private static let milestones = [10, 30, 50, 100, 200, 300, 500, 750, 1000, 2000, 3000, 5000, 10000]

    private var sessionReadCount: Int {
        session.undoStack.filter { $0.action == .read }.count
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
            checkMilestone: checkMilestoneAchievement,
            hasGradientBackground: hasGradient
        ) {
            completionAnimated = false
            achievementAnimated = false
            streakAchievement = nil
            milestoneAchievement = nil
            session.items = filteredUnreadEntries()
            session.currentIndex = 0
            session.undoStack = []
        }
    }

    private func updateBackgroundGradient() {
        // 前回のタスクをキャンセルして多重実行を防ぐ
        gradientTask?.cancel()

        guard session.currentIndex < session.items.count else { return }
        let entry = session.items[session.currentIndex]
        guard let imageData = entry.imageData else {
            let gradient = ImageColorExtractor.gradientFromColor(Color.fromName(entry.iconColor))
            withAnimation(.easeInOut(duration: 0.5)) {
                backgroundGradient = gradient
            }
            return
        }
        gradientTask = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else { return }
            let gradient = ImageColorExtractor.extractGradient(from: imageData)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    backgroundGradient = gradient
                }
            }
        }
    }

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener(
            browserMode: browserMode,
            openURL: openURL,
            onSafariURL: { safariURL = $0 },
            onQuickView: { quickViewContext = $0 },
            entryLookup: { url in
                guard let e = viewModel.allEntries().first(where: { $0.url == url }) else { return nil }
                return (e.name, e.publisher, e.imageData)
            }
        ).open(urlString)
    }
}

/// CatchUp のカード送り状態。View から切り出してテスト可能にしている。
struct CatchUpSession {
    enum Action { case read, skip }

    var items: [MangaEntry] = []
    var currentIndex = 0
    var undoStack: [(entry: MangaEntry, action: Action)] = []
    /// スワイプ確定待ちの作品。アニメーション後の確定までの間に入るリロードや連打に備える
    private(set) var pendingEntryID: UUID?

    var isBusy: Bool { pendingEntryID != nil }

    /// 現在のカードを確定対象として予約する。確定待ち中・範囲外なら false。
    mutating func beginSwipe() -> Bool {
        guard !isBusy, currentIndex < items.count else { return false }
        pendingEntryID = items[currentIndex].id
        return true
    }

    /// 予約した作品を確定して次へ進める。既読にすべき作品 (.read のとき) を返す。
    /// 確定待ちの間にリロードで並びが変わっても、予約した作品に作用させる。
    mutating func completeSwipe(_ action: Action) -> MangaEntry? {
        guard let id = pendingEntryID else { return nil }
        pendingEntryID = nil
        guard currentIndex <= items.count,
              let index = items[currentIndex...].firstIndex(where: { $0.id == id }) else { return nil }
        let entry = items.remove(at: index)
        items.insert(entry, at: currentIndex)
        undoStack.append((entry: entry, action: action))
        currentIndex += 1
        return action == .read ? entry : nil
    }
}
