import SwiftUI

/// ライブラリの「最近のメモ・コメント」セクションから「すべて表示」した先の画面。
/// メモとコメントの全件を時系列ミックスで表示する。
struct AllActivityView: View {
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var items: [ActivityItem] {
        let _ = viewModel.refreshCounter
        return ActivityBuilder.all(
            entries: viewModel.allEntries(),
            comments: viewModel.allComments()
        )
    }

    var body: some View {
        ZStack {
            if theme.usesCustomSurface {
                theme.surface.ignoresSafeArea()
            }
            List {
                ForEach(items) { item in
                    Button {
                        switch item {
                        case .memo(let entry):
                            editingEntry = entry
                        case .comment(_, let entry):
                            commentingEntry = entry
                        }
                    } label: {
                        ActivityRowView(item: item)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("メモ・コメント")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
