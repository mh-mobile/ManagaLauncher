import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settingsViewModel: MangaViewModel?

    var body: some View {
        TabView {
            Tab("ホーム", systemImage: "house.fill") {
                ContentView()
            }

            Tab("ライブラリ", systemImage: "books.vertical.fill") {
                LibraryView()
            }

            Tab("設定", systemImage: "gearshape.fill") {
                if let settingsViewModel {
                    SettingsView(viewModel: settingsViewModel, showsCloseButton: false)
                }
            }

            Tab(role: .search) {
                SearchView()
            }
        }
        .onAppear {
            if settingsViewModel == nil {
                settingsViewModel = MangaViewModel(modelContext: modelContext)
            }
        }
    }
}
