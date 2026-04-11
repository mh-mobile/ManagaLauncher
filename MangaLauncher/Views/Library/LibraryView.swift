import SwiftUI
import SwiftData
import PlatformKit

struct LibraryView: View {
    @Environment(\.openURL) private var openURL

    var viewModel: MangaViewModel
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @State private var safariURL: URL?
    @State private var showingAddSheet = false
    @AppStorage("browserMode") private var browserMode: String = "external"

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        NavigationStack {
            ZStack {
                if ThemeManager.shared.style.usesCustomSurface {
                    ThemeManager.shared.style.surface
                        .ignoresSafeArea()
                }

                content(viewModel: viewModel)
            }
            .navigationTitle("ライブラリ")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EditEntryView(viewModel: viewModel, day: .today)
            }
            .sheet(item: $editingEntry) { entry in
                EditEntryView(viewModel: viewModel, entry: entry)
            }
            .sheet(item: $commentingEntry) { entry in
                CommentListView(entry: entry, viewModel: viewModel)
            }
            #if canImport(UIKit)
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            #endif
        }
        .onMangaDataChange {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private func content(viewModel: MangaViewModel) -> some View {
        let _ = viewModel.refreshCounter
        // 1 度だけ fetch して使い回す（N+1 fetch を避ける）
        let allEntries = viewModel.allEntries()
        let allComments = viewModel.allComments()
        let sections = LibrarySectionBuilder(allEntries: allEntries).build()
        let recentActivity = ActivityBuilder.recent(entries: allEntries, comments: allComments, limit: 8)
        let totalActivityCount = ActivityBuilder.totalCount(entries: allEntries, comments: allComments)

        if sections.isEmpty && recentActivity.isEmpty {
            ContentUnavailableView {
                Label("ライブラリは空です", systemImage: "books.vertical")
                    .foregroundStyle(theme.onSurfaceVariant)
            } description: {
                Text("マンガを追加するとここに表示されます")
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if !recentActivity.isEmpty {
                        recentActivitySection(items: recentActivity, totalCount: totalActivityCount)
                    }
                    ForEach(sections) { section in
                        sectionView(section: section, viewModel: viewModel)
                    }
                }
                .padding(.vertical)
            }
            .navigationDestination(for: LibraryDestination.self) { destination in
                libraryDestinationView(destination, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func libraryDestinationView(_ destination: LibraryDestination, viewModel: MangaViewModel) -> some View {
        switch destination {
        case .allActivity:
            AllActivityView(
                viewModel: viewModel,
                editingEntry: $editingEntry,
                commentingEntry: $commentingEntry
            )
        case .allPublishers:
            AllPublishersView(
                viewModel: viewModel,
                editingEntry: $editingEntry,
                commentingEntry: $commentingEntry,
                onOpenURL: { openMangaURL($0) }
            )
        }
    }

    @ViewBuilder
    private func recentActivitySection(items: [ActivityItem], totalCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(
                title: "最近のメモ・コメント",
                icon: "square.and.pencil",
                iconColor: .purple,
                count: totalCount,
                badgeColor: .purple,
                seeAll: totalCount > items.count ? LibraryDestination.allActivity : nil
            )
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    activityRow(item)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func activityRow(_ item: ActivityItem) -> some View {
        Button {
            switch item {
            case .memo(let entry): editingEntry = entry
            case .comment(_, let entry): commentingEntry = entry
            }
        } label: {
            ActivityRowView(item: item)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionView(section: LibrarySection, viewModel: MangaViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(
                title: section.title,
                icon: section.icon,
                iconColor: section.iconColor,
                count: section.totalCount,
                seeAll: section.seeAll
            )
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(section.entries, id: \.id) { entry in
                        LibraryCard(
                            entry: entry,
                            viewModel: viewModel,
                            editingEntry: $editingEntry,
                            commentingEntry: $commentingEntry,
                            onOpenURL: { openMangaURL($0) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func openMangaURL(_ urlString: String) {
        MangaURLOpener(browserMode: browserMode, openURL: openURL) { safariURL = $0 }.open(urlString)
    }
}
