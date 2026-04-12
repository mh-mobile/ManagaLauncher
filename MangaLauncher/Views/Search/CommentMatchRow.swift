import SwiftUI

/// 検索結果「コメント」セクションの 1 行。タップで該当作品の CommentListView へ。
struct CommentMatchRow: View {
    let comment: MangaComment
    let entry: MangaEntry
    let query: String
    @Binding var commentingEntry: MangaEntry?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Button {
            commentingEntry = entry
        } label: {
            HStack(alignment: .top, spacing: 12) {
                EntryIcon(entry: entry, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.name)
                            .font(theme.subheadlineFont.bold())
                            .foregroundStyle(theme.onSurface)
                            .lineLimit(1)
                        Spacer()
                        Text(comment.createdAt.formatted(.relative(presentation: .named)))
                            .font(theme.caption2Font)
                            .foregroundStyle(theme.onSurfaceVariant)
                    }
                    Text(SearchSnippet.make(from: comment.content, query: query))
                        .font(theme.captionFont)
                        .foregroundStyle(theme.onSurfaceVariant)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Image(systemName: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(theme.onSurfaceVariant.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
