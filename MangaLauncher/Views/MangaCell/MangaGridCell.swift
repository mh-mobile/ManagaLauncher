import SwiftUI
import PlatformKit

struct MangaGridCell: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    let hasWallpaper: Bool
    let reduceTransparency: Bool
    @Binding var isGridEditMode: Bool
    @Binding var editingEntry: MangaEntry?
    let onOpenURL: (String) -> Void

    var body: some View {
        if entry.isDeleted || entry.modelContext == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Manga Panel Image
                ZStack(alignment: .topLeading) {
                    if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius))
                    } else {
                        RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                            .fill(Color.fromName(entry.iconColor))
                            .aspectRatio(3/4, contentMode: .fit)
                            .overlay {
                                ZStack {
                                    ScreenTonePattern(opacity: 0.08, spacing: 4)
                                    Text(entry.name)
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(8)
                                }
                            }
                    }

                    // Unread badge
                    if !entry.isRead {
                        Text("NEW")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(InkTheme.onPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(InkTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .offset(x: 4, y: 4)
                    }
                }

                // Title area
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(InkTheme.onSurface)
                        .lineLimit(2)
                    if !entry.publisher.isEmpty {
                        Text(entry.publisher)
                            .font(.system(size: 10))
                            .foregroundStyle(InkTheme.onSurfaceVariant)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(InkTheme.surfaceContainerHighest)
            }
            .clipShape(RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius))
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.name)\(entry.publisher.isEmpty ? "" : "、\(entry.publisher)")\(entry.isRead ? "" : "、未読")")
            .accessibilityHint("タップでサイトを開く")
            .onTapGesture {
                if isGridEditMode {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGridEditMode = false
                    }
                } else {
                    onOpenURL(entry.url)
                }
            }
            .contextMenu {
                MangaContextMenu(entry: entry, viewModel: viewModel, editingEntry: $editingEntry) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGridEditMode = true
                    }
                }
            }
        }
    }
}
