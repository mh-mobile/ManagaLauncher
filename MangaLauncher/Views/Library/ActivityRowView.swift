import SwiftUI

/// 「最近のメモ・コメント」セクションで使う 1 行 UI。
/// メモかコメントかで色とアイコンが切り替わる。
struct ActivityRowView: View {
    enum Kind { case memo, comment }

    let kind: Kind
    let title: String
    let content: String
    let timestamp: Date?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var accentColor: Color {
        switch kind {
        case .memo: return .orange
        case .comment: return .blue
        }
    }

    private var iconName: String {
        switch kind {
        case .memo: return "note.text"
        case .comment: return "bubble.left.fill"
        }
    }

    private var kindLabel: String {
        switch kind {
        case .memo: return "メモ"
        case .comment: return "コメント"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.caption2)
                        .foregroundStyle(accentColor)
                    Text(kindLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(accentColor)
                        .clipShape(Capsule())
                    Text(title)
                        .font(theme.subheadlineFont.bold())
                        .foregroundStyle(theme.onSurface)
                        .lineLimit(1)
                    Spacer()
                    if let timestamp {
                        Text(timestamp.formatted(.relative(presentation: .named)))
                            .font(theme.caption2Font)
                            .foregroundStyle(theme.onSurfaceVariant)
                    }
                }
                Text(content)
                    .font(theme.captionFont)
                    .foregroundStyle(theme.onSurfaceVariant)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.15), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension ActivityRowView {
    /// ActivityItem から直接行を作る便利初期化
    init(item: ActivityItem) {
        switch item {
        case .memo(let entry):
            self.init(kind: .memo, title: entry.name, content: entry.memo, timestamp: entry.memoUpdatedAt)
        case .comment(let comment, let entry):
            self.init(kind: .comment, title: entry.name, content: comment.content, timestamp: comment.createdAt)
        }
    }
}
