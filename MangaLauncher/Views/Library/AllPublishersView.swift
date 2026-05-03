import SwiftUI

/// ライブラリの「掲載誌別」セクションから「すべて表示」した先の画面。
/// 全掲載誌を登録数の多い順に表示。タップで該当誌の作品一覧へ。
struct AllPublishersView: View {
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    private var theme: ThemeStyle { ThemeManager.shared.style }

    @State private var publisherCounts: [(publisher: String, count: Int)] = []
    @State private var mergeSource: String = ""
    @State private var showingMergeSheet = false
    @State private var iconEditTarget: String?

    var body: some View {
        ZStack {
            if theme.usesCustomSurface {
                theme.surface.ignoresSafeArea()
            }
            List {
                ForEach(publisherCounts, id: \.publisher) { item in
                    NavigationLink(value: PublisherSelection(name: item.publisher)) {
                        HStack {
                            PublisherIconView(
                                iconData: viewModel.publisherIcon(for: item.publisher),
                                size: 28,
                                showsFallback: true
                            )
                            Text(item.publisher)
                                .font(theme.bodyFont)
                                .foregroundStyle(theme.onSurface)
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(theme.onPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(theme.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        Button {
                            iconEditTarget = item.publisher
                        } label: {
                            Label("掲載誌アイコンを設定", systemImage: "photo.badge.plus")
                        }
                        Button {
                            mergeSource = item.publisher
                            showingMergeSheet = true
                        } label: {
                            Label("他の掲載誌に統合", systemImage: "arrow.triangle.merge")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("掲載誌")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { refreshPublisherCounts() }
        .onChange(of: viewModel.refreshCounter) { _, _ in refreshPublisherCounts() }
        .navigationDestination(for: PublisherSelection.self) { selection in
            PublisherEntriesView(
                publisher: selection.name,
                viewModel: viewModel,
                editingEntry: $editingEntry,
                commentingEntry: $commentingEntry,
                onOpenURL: onOpenURL
            )
        }
        .sheet(isPresented: $showingMergeSheet) {
            PublisherMergePickerView(
                source: mergeSource,
                publishers: publisherCounts.map(\.publisher),
                viewModel: viewModel
            )
        }
        .sheet(item: Binding(
            get: { iconEditTarget.map { PublisherSelection(name: $0) } },
            set: { iconEditTarget = $0?.name }
        )) { selection in
            PublisherIconEditorView(publisherName: selection.name, viewModel: viewModel)
        }
    }

    private func refreshPublisherCounts() {
        publisherCounts = PublisherIndex.counts(from: viewModel.allEntries())
    }
}

struct PublisherSelection: Hashable, Identifiable {
    let name: String
    var id: String { name }
}

/// 個別の掲載誌に紐付くマンガ一覧画面
struct PublisherEntriesView: View {
    let publisher: String
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    @State private var lifetimeEntry: MangaEntry?
    @State private var showSpecialEpisodeAlert = false
    @State private var specialEpisodeEntry: MangaEntry?
    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var entries: [MangaEntry] {
        let _ = viewModel.refreshCounter
        return viewModel.allEntries().filter { $0.publisher == publisher }
    }

    var body: some View {
        ZStack {
            if theme.usesCustomSurface {
                theme.surface.ignoresSafeArea()
            }
            List {
                ForEach(entries, id: \.id) { entry in
                    Button {
                        onOpenURL(entry.url)
                    } label: {
                        HStack(spacing: 12) {
                            EntryIcon(entry: entry, size: 40)
                            Text(entry.name)
                                .font(theme.bodyFont)
                                .foregroundStyle(theme.onSurface)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(theme.onSurfaceVariant.opacity(0.5))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry, commentingEntry: $commentingEntry, links: viewModel.fetchLinks(for: entry), onShowLifetime: { lifetimeEntry = entry }, onRecordSpecialEpisode: {
                            specialEpisodeEntry = entry
                            showSpecialEpisodeAlert = true
                        })
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(publisher)
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .if(specialEpisodeEntry != nil || !entries.isEmpty) { view in
            view.specialEpisodeAlert(entry: specialEpisodeEntry ?? entries[0], viewModel: viewModel, isPresented: $showSpecialEpisodeAlert)
        }
    }
}
