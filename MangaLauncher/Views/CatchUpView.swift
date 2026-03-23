import SwiftUI

struct CatchUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var viewModel: MangaViewModel
    let day: DayOfWeek

    @State private var unreadItems: [MangaEntry] = []
    @State private var currentIndex: Int = 0
    @State private var offset: CGSize = .zero
    @State private var undoStack: [(entry: MangaEntry, action: SwipeAction)] = []

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
            .navigationTitle("\(day.displayName)のキャッチアップ")
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
                unreadItems = viewModel.unreadEntries(for: day)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mangaDataDidChange)) { _ in
            reloadEntries()
        }
    }

    // MARK: - Card Stack

    private var cardStackView: some View {
        VStack(spacing: 20) {
            // Progress
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

            // Cards
            ZStack {
                // Next card (background)
                if currentIndex + 1 < totalCount {
                    cardView(for: unreadItems[currentIndex + 1])
                        .scaleEffect(0.95)
                        .opacity(0.5)
                }

                // Current card
                cardView(for: unreadItems[currentIndex])
                    .offset(offset)
                    .rotationEffect(.degrees(Double(offset.width) / 20))
                    .overlay {
                        swipeOverlay
                    }
                    .gesture(dragGesture)
            }
            .padding(.horizontal)

            // Action buttons
            HStack(spacing: 60) {
                // Skip (left)
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

                // Read (right)
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
        }
    }

    // MARK: - Card View

    private func cardView(for entry: MangaEntry) -> some View {
        VStack(spacing: 12) {
            if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorFromName(entry.iconColor))
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        Text(entry.name)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
            }

            Text(entry.name)
                .font(.title3.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if !entry.publisher.isEmpty {
                Text(entry.publisher)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: entry.url) {
                openURL(url)
            }
        }
    }

    // MARK: - Swipe Overlay

    @ViewBuilder
    private var swipeOverlay: some View {
        if offset.width > 30 {
            RoundedRectangle(cornerRadius: 16)
                .fill(.green.opacity(0.2))
                .overlay {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("既読")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }
                }
                .opacity(min(Double(offset.width) / 100, 1))
        } else if offset.width < -30 {
            RoundedRectangle(cornerRadius: 16)
                .fill(.orange.opacity(0.2))
                .overlay {
                    VStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                        Text("あとで")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .opacity(min(Double(-offset.width) / 100, 1))
        }
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
        let entry = unreadItems[currentIndex]
        undoStack.append((entry: entry, action: action))

        if action == .read {
            viewModel.markAsRead(entry)
        }

        offset = .zero
        currentIndex += 1
    }

    private func reloadEntries() {
        let processedIDs = Set(undoStack.filter { $0.action == .read }.map { $0.entry.id })
        let allUnread = viewModel.unreadEntries(for: day)
        var newItems: [MangaEntry] = []

        // Keep already-processed entries in order
        for i in 0..<currentIndex where i < unreadItems.count {
            let oldEntry = unreadItems[i]
            if let fresh = viewModel.findEntry(by: oldEntry.id) {
                newItems.append(fresh)
            }
        }

        // Remaining unread entries
        for entry in allUnread where !processedIDs.contains(entry.id) && !newItems.contains(where: { $0.id == entry.id }) {
            newItems.append(entry)
        }

        unreadItems = newItems
        // Rebuild undo stack with fresh references
        undoStack = undoStack.compactMap { item in
            guard let fresh = viewModel.findEntry(by: item.entry.id) else { return nil }
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

    private func completedView(message: String) -> some View {
        let remainingUnread = viewModel.unreadCount(for: day)
        return VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text(message)
                .font(.title2.bold())
            if remainingUnread > 0 {
                Button {
                    unreadItems = viewModel.unreadEntries(for: day)
                    currentIndex = 0
                    undoStack = []
                } label: {
                    Label("未読を再チェック（\(remainingUnread)件）", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        default: .blue
        }
    }
}
