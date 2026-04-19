import SwiftUI
import PlatformKit

struct HiddenEntriesView: View {
    var viewModel: MangaViewModel
    @State private var isAuthenticated = false
    @State private var entries: [MangaEntry] = []
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @State private var lifetimeEntry: MangaEntry?

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
        } else {
            List {
                ForEach(entries, id: \.id) { entry in
                    HStack(spacing: 12) {
                        if let data = entry.imageData, let image = data.toSwiftUIImage() {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.fromName(entry.iconColor))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(entry.name.prefix(1))
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                }
                        }
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
                    .swipeActions(edge: .trailing) {
                        Button {
                            unhide(entry)
                        } label: {
                            Label("解除", systemImage: "eye")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
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
                }
            }
            .listStyle(.plain)
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
