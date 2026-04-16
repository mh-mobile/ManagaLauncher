import SwiftUI

/// 検索画面の上 2 行のフィルタチップバー。
/// - 1 行目: 掲載状況 (連載中/休載中/完結/読み切り) と読書状況 (追っかけ中/積読/読了)
/// - 2 行目: メモ/コメントモード切替 + カラーフィルタ
struct SearchFilterBars: View {
    @Binding var publicationFilter: PublicationStatus?
    @Binding var readingFilter: ReadingState?
    @Binding var showOneShotOnly: Bool
    @Binding var contentMode: SearchContentMode
    @Binding var selectedColors: Set<String>

    private let colorLabelStore = ColorLabelStore.shared
    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        VStack(spacing: 0) {
            stateFilterBar
            secondaryFilterBar
        }
    }

    // MARK: - 行 1: 状態フィルタ (2 軸)

    @ViewBuilder
    private var stateFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PublicationStatus.allCases) { status in
                    filterChip(label: status.displayName, isSelected: !showOneShotOnly && publicationFilter == status) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            contentMode = .entries
                            showOneShotOnly = false
                            publicationFilter = publicationFilter == status ? nil : status
                        }
                    }
                }
                filterChip(label: "読み切り", isSelected: showOneShotOnly) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        contentMode = .entries
                        if showOneShotOnly {
                            showOneShotOnly = false
                        } else {
                            showOneShotOnly = true
                            publicationFilter = nil
                        }
                    }
                }

                Spacer().frame(width: 12)

                ForEach(ReadingState.allCases) { state in
                    filterChip(label: state.displayName, isSelected: readingFilter == state) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            contentMode = .entries
                            readingFilter = readingFilter == state ? nil : state
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 行 2: メモ/コメント + カラー

    @ViewBuilder
    private var secondaryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "メモ", isSelected: contentMode == .memo) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if contentMode == .memo {
                            contentMode = .entries
                        } else {
                            contentMode = .memo
                            clearEntryFilters()
                        }
                    }
                }
                filterChip(label: "コメント", isSelected: contentMode == .comment) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if contentMode == .comment {
                            contentMode = .entries
                        } else {
                            contentMode = .comment
                            clearEntryFilters()
                        }
                    }
                }

                ForEach(MangaColor.all) { mangaColor in
                    colorChip(for: mangaColor)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func colorChip(for mangaColor: MangaColor) -> some View {
        let isSelected = selectedColors.contains(mangaColor.name)
        let label = colorLabelStore.label(for: mangaColor.name)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSelected {
                    selectedColors.remove(mangaColor.name)
                } else {
                    selectedColors.insert(mangaColor.name)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(mangaColor.color)
                    .frame(width: 14, height: 14)
                if let label {
                    Text(label).font(theme.captionFont)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(theme.primary.opacity(0.2))
                    : AnyShapeStyle(theme.surfaceContainerHigh)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? theme.primary : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(theme.onSurface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(theme.bodyFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? AnyShapeStyle(theme.primary)
                        : AnyShapeStyle(theme.surfaceContainerHigh)
                )
                .foregroundStyle(isSelected ? theme.onPrimary : theme.onSurface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func clearEntryFilters() {
        publicationFilter = nil
        readingFilter = nil
        showOneShotOnly = false
    }
}

/// SearchView と SearchFilterBars で共有する検索コンテンツモード。
enum SearchContentMode {
    case entries, memo, comment
}
