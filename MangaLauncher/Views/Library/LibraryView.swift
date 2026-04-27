import SwiftUI
import PlatformKit

struct LibraryView: View {
    @Environment(\.openURL) private var openURL

    var viewModel: MangaViewModel
    @State private var editingEntry: MangaEntry?
    @State private var commentingEntry: MangaEntry?
    @State private var safariURL: URL?
    @State private var showingAddSheet = false
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"
    @AppStorage(UserDefaultsKeys.showHiddenSection) private var showHiddenSection: Bool = true
    @AppStorage(UserDefaultsKeys.recentActivityExpanded) private var recentActivityExpandedStorage: Bool = false
    @State private var recentActivityExpanded: Bool = false

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
                SafariView(url: url).ignoresSafeArea()
            }
            #endif
            .onAppear {
                recentActivityExpanded = recentActivityExpandedStorage
            }
            .onChange(of: recentActivityExpanded) { _, newValue in
                recentActivityExpandedStorage = newValue
            }
        }
        .onMangaDataChange {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private func content(viewModel: MangaViewModel) -> some View {
        let _ = viewModel.refreshCounter
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
                    timelineLink
                    hiddenSectionLink
                    recentlyDeletedLink
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
        case .timeline:
            TimelineView(viewModel: viewModel)
        case .hiddenEntries:
            HiddenEntriesView(viewModel: viewModel)
        case .recentlyDeleted:
            RecentlyDeletedView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var timelineLink: some View {
        NavigationLink(value: LibraryDestination.timeline) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 6))
                Text("タイムライン")
                    .font(theme.subheadlineFont.weight(.semibold))
                    .foregroundStyle(theme.onSurface)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.onSurfaceVariant)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surfaceContainerHigh)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var hiddenSectionLink: some View {
        if showHiddenSection {
            NavigationLink(value: LibraryDestination.hiddenEntries) {
                HStack(spacing: 10) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.gray, in: RoundedRectangle(cornerRadius: 6))
                    Text("非表示")
                        .font(theme.subheadlineFont.weight(.semibold))
                        .foregroundStyle(theme.onSurface)
                    Spacer()
                    let count = viewModel.hiddenIDs.count
                    if count > 0 {
                        Text("\(count)")
                            .font(theme.captionFont)
                            .foregroundStyle(theme.onSurfaceVariant)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(theme.onSurfaceVariant)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.surfaceContainerHigh)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var recentlyDeletedLink: some View {
        let count = viewModel.deletedEntryCount()
        if count > 0 {
            NavigationLink(value: LibraryDestination.recentlyDeleted) {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 6))
                    Text("最近削除した項目")
                        .font(theme.subheadlineFont.weight(.semibold))
                        .foregroundStyle(theme.onSurface)
                    Spacer()
                    Text("\(count)")
                        .font(theme.captionFont)
                        .foregroundStyle(theme.onSurfaceVariant)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(theme.onSurfaceVariant)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.surfaceContainerHigh)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func recentActivitySection(items: [ActivityItem], totalCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(theme.headlineFont)
                    .foregroundStyle(.purple)
                NavigationLink(value: LibraryDestination.allActivity) {
                    HStack(spacing: 8) {
                        Text("メモ・コメント")
                            .font(theme.title3Font)
                            .foregroundStyle(theme.onSurface)
                        Text("\(totalCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.onPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.purple)
                            .clipShape(Capsule())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.onSurfaceVariant)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        recentActivityExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.primary)
                        .rotationEffect(.degrees(recentActivityExpanded ? 0 : -90))
                        .frame(width: 30, height: 30)
                        .background(theme.onSurfaceVariant.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            if recentActivityExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        activityRow(item)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
            }
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
        MangaURLOpener.make(
            browserMode: browserMode,
            openURL: openURL,
            safariURL: $safariURL,
            viewModel: viewModel
        ).open(urlString)
    }
}
