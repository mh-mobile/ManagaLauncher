import SwiftUI
import PlatformKit

struct HiddenEntriesView: View {
    @Environment(\.openURL) private var openURL
    var viewModel: MangaViewModel
    @State private var isAuthenticated = false
    @State private var entries: [MangaEntry] = []
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @State private var lifetimeEntry: MangaEntry?
    @State private var safariURL: URL?
    @State private var showGrid = false
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Group {
            if isAuthenticated {
                authenticatedContent
            } else {
                lockedView
            }
        }
        .themedNavigationStyle()
        .navigationTitle("非表示")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if isAuthenticated && !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            showGrid.toggle()
                        }
                    } label: {
                        Image(systemName: showGrid ? "list.bullet" : "square.grid.2x2")
                    }
                }
            }
        }
        .onAppear { authenticate() }
        .sheet(item: $editingEntry) { entry in
            EditEntryView(viewModel: viewModel, entry: entry)
        }
        .sheet(item: $commentingEntry) { entry in
            CommentListView(entry: entry, viewModel: viewModel)
        }
        .sheet(item: $lifetimeEntry) { entry in
            let lifetime = LifetimeBuilder.build(
                entries: [entry],
                activities: viewModel.allActivities(),
                comments: viewModel.allComments()
            ).first ?? MangaLifetime(entry: entry, startDate: Date(), endDate: Date(), activityCount: 0)
            LifetimeDetailSheet(lifetime: lifetime, viewModel: viewModel)
        }
        #if canImport(UIKit)
        .sheet(item: $safariURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        #endif
    }

    private func openMangaURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let entry = entries.first { $0.url == urlString }
        if browserMode == "overlay" {
            viewModel.browserContext = BrowserContext(url: url, entryName: entry?.name, entryPublisher: entry?.publisher, entryImageData: entry?.imageData)
        } else if browserMode == "inApp" {
            safariURL = url
        } else {
            openURL(url)
        }
    }

    @ViewBuilder
    private var lockedView: some View {
        ContentUnavailableView {
            Label("認証が必要です", systemImage: "lock.fill")
                .foregroundStyle(theme.onSurfaceVariant)
        } description: {
            Text("非表示のマンガを閲覧するには認証が必要です")
                .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
        } actions: {
            Button("認証する") { authenticate() }
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label("非表示のマンガはありません", systemImage: "eye.slash")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("マンガを長押し →「非表示にする」で追加できます")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        } else if showGrid {
            gridContent
        } else {
            listContent
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            ForEach(entries, id: \.id) { entry in
                HStack(spacing: 12) {
                    entryThumbnail(entry, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.onSurface)
                        if !entry.publisher.isEmpty {
                            Text(entry.publisher)
                                .font(theme.captionFont)
                                .foregroundStyle(theme.onSurfaceVariant)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    openMangaURL(entry.url)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        unhide(entry)
                    } label: {
                        Label("解除", systemImage: "eye")
                    }
                    .tint(.blue)
                }
                .contextMenu { entryContextMenu(entry) }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var gridContent: some View {
        GeometryReader { geo in
            ScrollView {
                MasonryLayout(entries: entries, availableWidth: geo.size.width - 32) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        if let data = entry.imageData, let image = data.toSwiftUIImage() {
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.fromName(entry.iconColor))
                                .aspectRatio(3 / 4, contentMode: .fit)
                                .overlay {
                                    Text(entry.name)
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(8)
                                }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.caption)
                                .foregroundStyle(theme.onSurface)
                                .lineLimit(2)
                            if !entry.publisher.isEmpty {
                                Text(entry.publisher)
                                    .font(.caption2)
                                    .foregroundStyle(theme.onSurfaceVariant)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openMangaURL(entry.url)
                    }
                    .contextMenu { entryContextMenu(entry) }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func entryThumbnail(_ entry: MangaEntry, size: CGFloat) -> some View {
        if let data = entry.imageData, let image = data.toSwiftUIImage() {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.fromName(entry.iconColor))
                .frame(width: size, height: size)
                .overlay {
                    Text(entry.name.prefix(1))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
        }
    }

    @ViewBuilder
    private func entryContextMenu(_ entry: MangaEntry) -> some View {
        Button {
            unhide(entry)
        } label: {
            Label("非表示を解除", systemImage: "eye")
        }

        Divider()

        Button { editingEntry = entry } label: {
            Label("編集", systemImage: "pencil")
        }
        Button { commentingEntry = entry } label: {
            Label("コメント", systemImage: "bubble.left.and.bubble.right")
        }
        Button { lifetimeEntry = entry } label: {
            Label("ライフタイムを見る", systemImage: "chart.bar.xaxis")
        }
    }

    private func unhide(_ entry: MangaEntry) {
        viewModel.setHidden(entry, isHidden: false)
        withAnimation {
            entries.removeAll { $0.id == entry.id }
        }
    }

    private func authenticate() {
        Task {
            let success = await BiometricAuthService.authenticate(
                reason: "非表示のマンガを表示するために認証が必要です"
            )
            isAuthenticated = success
            if success {
                entries = viewModel.hiddenEntries()
            }
        }
    }
}
