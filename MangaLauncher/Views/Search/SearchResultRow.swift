import SwiftUI

/// 検索結果「マンガ」セクションの 1 行
struct SearchResultRow: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    @State private var lifetimeEntry: MangaEntry?
    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Button {
            onOpenURL(entry.url)
        } label: {
            HStack(spacing: 12) {
                EntryIcon(entry: entry, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if !entry.isRead {
                            Circle()
                                .fill(theme.badgeColor)
                                .frame(width: 6, height: 6)
                        }
                        Text(entry.name)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.onSurface)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        if !entry.publisher.isEmpty {
                            Text(entry.publisher)
                                .font(theme.captionFont)
                                .foregroundStyle(theme.onSurfaceVariant)
                        }
                        MangaStatusBadgeView(entry: entry, fontSize: 9)
                        if !hasAnyStatus(entry) {
                            dayBadge(entry.dayOfWeek.shortName)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contextMenu {
            MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry, commentingEntry: $commentingEntry, onShowLifetime: { lifetimeEntry = entry })
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

    /// マンガに状態バッジが付くか（連載追っかけ中なら付かない）
    private func hasAnyStatus(_ entry: MangaEntry) -> Bool {
        entry.readingState == .archived
            || entry.publicationStatus == .finished
            || entry.publicationStatus == .hiatus
            || entry.readingState == .backlog
            || entry.isOneShot
    }

    private func dayBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(theme.onSurfaceVariant.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
