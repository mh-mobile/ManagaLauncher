import SwiftUI
import PlatformKit

struct LibraryCard: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    @State private var lifetimeEntry: MangaEntry?
    @State private var showSpecialEpisodeAlert = false
    private var theme: ThemeStyle { ThemeManager.shared.style }
    private let cardWidth: CGFloat = 130

    var body: some View {
        Button {
            onOpenURL(entry.url)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                cardImage
                    .frame(width: cardWidth, height: cardWidth * 3 / 4)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if !entry.isRead {
                            Circle()
                                .fill(theme.badgeColor)
                                .frame(width: 8, height: 8)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        MangaStatusBadgeView(entry: entry, fontSize: 10)
                            .padding(4)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if let text = entry.episodeDisplayText {
                            Text(text)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(theme.onPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(theme.primary.opacity(0.85))
                                )
                                .padding(4)
                        }
                    }

                Text(entry.name)
                    .font(theme.captionFont)
                    .foregroundStyle(theme.onSurface)
                    .lineLimit(1)
                    .frame(width: cardWidth, alignment: .leading)

                if !entry.publisher.isEmpty {
                    Text(entry.publisher)
                        .font(theme.caption2Font)
                        .foregroundStyle(theme.onSurfaceVariant)
                        .lineLimit(1)
                        .frame(width: cardWidth, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry, commentingEntry: $commentingEntry, links: viewModel.fetchLinks(for: entry), onShowLifetime: { lifetimeEntry = entry }, onRecordSpecialEpisode: { showSpecialEpisodeAlert = true })
        }
        .specialEpisodeAlert(entry: entry, viewModel: viewModel, isPresented: $showSpecialEpisodeAlert)
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
    private var cardImage: some View {
        if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
            image
                .resizable()
                .scaledToFill()
        } else {
            Color.fromName(entry.iconColor)
                .overlay {
                    Text(entry.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(6)
                }
        }
    }

}
