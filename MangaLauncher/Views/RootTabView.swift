import SwiftUI

struct RootTabView: View {
    var viewModel: MangaViewModel

    var body: some View {
        TabView {
            Tab("ホーム", systemImage: "house.fill") {
                ContentView(viewModel: viewModel)
            }

            Tab("ライブラリ", systemImage: "books.vertical.fill") {
                LibraryView(viewModel: viewModel)
            }

            Tab("設定", systemImage: "gearshape.fill") {
                SettingsView(viewModel: viewModel, showsCloseButton: false)
            }

            Tab(role: .search) {
                SearchView(viewModel: viewModel)
            }
        }
        // どのタブから削除してもトーストが表示されるように全体 overlay で保持
        .overlay(alignment: .bottom) {
            if !viewModel.pendingDeleteEntries.isEmpty {
                DeleteToastView(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80) // ボトムタブを避ける
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.pendingDeleteEntries.isEmpty)
    }
}
