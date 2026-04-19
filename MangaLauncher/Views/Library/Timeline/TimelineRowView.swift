import SwiftUI

/// TimelineView の 1 行。時刻ラベル + 縦線 + タイプアイコン + 内容カード。
struct TimelineRowView: View {
    let item: TimelineItem
    let isFirst: Bool
    let isLast: Bool
    var onTap: () -> Void = {}

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeColumn
            connector
            card
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    // MARK: - Time label (left column)
    @ViewBuilder
    private var timeColumn: some View {
        Text(item.hasPreciseTime ? Self.timeFormatter.string(from: item.timestamp) : "--:--")
            .font(theme.captionFont.monospacedDigit())
            .foregroundStyle(item.hasPreciseTime ? theme.onSurfaceVariant : theme.onSurfaceVariant.opacity(0.5))
            .frame(width: 42, alignment: .trailing)
            .padding(.top, 2)
    }

    // MARK: - Vertical connector with dot/icon
    @ViewBuilder
    private var connector: some View {
        VStack(spacing: 0) {
            // top half line
            Rectangle()
                .fill(isFirst ? Color.clear : theme.onSurfaceVariant.opacity(0.25))
                .frame(width: 2)
                .frame(height: 8)

            // type icon in a circle
            Image(systemName: icon.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(icon.color, in: Circle())

            // bottom line (extends to next row)
            Rectangle()
                .fill(isLast ? Color.clear : theme.onSurfaceVariant.opacity(0.25))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Content card
    @ViewBuilder
    private var card: some View {
        HStack(alignment: .top, spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(item.mangaName)
                    .font(theme.subheadlineFont.weight(.semibold))
                    .foregroundStyle(theme.onSurface)
                    .lineLimit(1)
                content
                    .font(theme.captionFont)
                    .foregroundStyle(theme.onSurfaceVariant)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceContainerHigh)
        )
        .padding(.vertical, 2)
    }

    /// マンガの表紙サムネイル。画像がなければアイコンカラーの塊を返す。
    @ViewBuilder
    private var thumbnail: some View {
        let size: CGFloat = 40
        Group {
            if let entry = item.entry,
               let data = entry.imageData,
               let image = data.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFill()
            } else if let entry = item.entry {
                Color.fromName(entry.iconColor)
                    .overlay {
                        Text(entry.name.prefix(1))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
            } else {
                Color.fromName("blue").opacity(0.3)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var content: some View {
        switch item {
        case .comment(let comment, _):
            Text(comment.content)
        case .memo(let entry):
            if entry.memo.isEmpty {
                Text("(空)")
            } else {
                Text(entry.memo)
            }
        case .read(let activity, _):
            if let label = activity.episodeLabel, !label.isEmpty {
                Text(label)
            } else if let ep = activity.episodeNumber {
                Text("既読 \(ep)話に更新")
            } else {
                Text("読みました")
            }
        }
    }

    // MARK: - Icon / color per type
    private var icon: (name: String, color: Color) {
        switch item {
        case .comment: return ("bubble.left.fill", .blue)
        case .memo: return ("pencil", .orange)
        case .read(let activity, _):
            if activity.episodeNumber != nil {
                return ("book.fill", .purple)
            }
            return ("checkmark", .green)
        }
    }
}
