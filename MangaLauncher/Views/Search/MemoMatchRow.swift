import SwiftUI

/// 検索結果「メモ」セクションの 1 行。タップで編集画面へ。
struct MemoMatchRow: View {
    let entry: MangaEntry
    let query: String
    @Binding var editingEntry: MangaEntry?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Button {
            editingEntry = entry
        } label: {
            HStack(alignment: .top, spacing: 12) {
                EntryIcon(entry: entry, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(theme.subheadlineFont.bold())
                        .foregroundStyle(theme.onSurface)
                        .lineLimit(1)
                    Text(SearchSnippet.make(from: entry.memo, query: query))
                        .font(theme.captionFont)
                        .foregroundStyle(theme.onSurfaceVariant)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "note.text")
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
