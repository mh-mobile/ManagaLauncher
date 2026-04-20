import SwiftUI
#if canImport(UIKit)
import WebKit
#endif

enum RootTab: Hashable {
    case home, library, settings, search
}

struct RootTabView: View {
    var viewModel: MangaViewModel
    @State private var selectedTab: RootTab = .home
    @AppStorage(UserDefaultsKeys.hasSeenOnboarding) private var hasSeenOnboarding = false

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                hasSeenOnboarding = true
            }
        } else {
        TabView(selection: $selectedTab) {
            Tab("ホーム", systemImage: "house.fill", value: RootTab.home) {
                ContentView(viewModel: viewModel)
            }

            Tab("ライブラリ", systemImage: "books.vertical.fill", value: RootTab.library) {
                LibraryView(viewModel: viewModel)
            }

            Tab("設定", systemImage: "gearshape.fill", value: RootTab.settings) {
                SettingsView(viewModel: viewModel, showsCloseButton: false)
            }

            Tab(value: RootTab.search, role: .search) {
                SearchView(viewModel: viewModel)
            }
        }
        // iPad で sidebar adaptive な動作になると DayPagerView (内側の TabView) と
        // 干渉してレイアウトが破綻する報告があったため、iPhone と同じタブバーで固定する。
        // 将来 DayPagerView 周りを改善できたら .sidebarAdaptable に戻して
        // iPad の広い画面を活用できるようにしたい。
        .tabViewStyle(.tabBarOnly)
        // コントロールセンターからの曜日切替・キャッチアップは Home タブに切り替えてから反映する
        .onReceive(NotificationCenter.default.publisher(for: .switchToDay)) { _ in
            selectedTab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCatchUp)) { _ in
            selectedTab = .home
        }
        // どのタブから削除してもトーストが表示されるように全体 overlay で保持
        .overlay(alignment: .bottom) {
            if !viewModel.pendingDeleteEntries.isEmpty {
                DeleteToastView(
                    count: viewModel.pendingDeleteEntries.count,
                    onUndo: { viewModel.undoPendingDeletes() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 80) // ボトムタブを避ける
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.pendingDeleteEntries.isEmpty)
        // 移行 / インポート / 保存などの重大エラーをアプリ全体で 1 箇所に集約して alert
        .alert(
            viewModel.lastError?.title ?? "",
            isPresented: Binding(
                get: { viewModel.lastError != nil },
                set: { if !$0 { viewModel.lastError = nil } }
            ),
            presenting: viewModel.lastError
        ) { _ in
            Button("OK") { viewModel.lastError = nil }
        } message: { error in
            Text(error.message)
        }
        #if canImport(UIKit)
        .overlay {
            if let ctx = viewModel.browserContext {
                OverlayBrowserScreen(context: ctx) {
                    viewModel.browserContext = nil
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.browserContext != nil)
        #endif
        }
    }
}
