import SwiftUI

/// 掲載誌の統合先を選ぶピッカー。
/// source（移行元）以外の既存掲載誌を一覧表示し、タップで統合を実行する。
struct PublisherMergePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let source: String
    let publishers: [String]
    var viewModel: MangaViewModel

    @State private var pendingDestination: String?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    /// source 以外の掲載誌リスト
    private var destinations: [String] {
        publishers.filter { $0 != source }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if theme.usesCustomSurface {
                    theme.surface.ignoresSafeArea()
                }
                List {
                    Section {
                        HStack(spacing: 8) {
                            PublisherIconView(
                                iconData: viewModel.publisherIcon(for: source),
                                size: 22,
                                showsFallback: true
                            )
                            Text(source)
                                .font(theme.bodyFont.weight(.semibold))
                                .foregroundStyle(theme.onSurface)
                        }
                    } header: {
                        Text("統合元")
                    }

                    Section {
                        if destinations.isEmpty {
                            Text("他に掲載誌がありません")
                                .foregroundStyle(theme.onSurfaceVariant)
                        } else {
                            ForEach(destinations, id: \.self) { dest in
                                Button {
                                    pendingDestination = dest
                                } label: {
                                    HStack(spacing: 8) {
                                        PublisherIconView(
                                            iconData: viewModel.publisherIcon(for: dest),
                                            size: 22,
                                            showsFallback: true
                                        )
                                        Text(dest)
                                            .font(theme.bodyFont)
                                            .foregroundStyle(theme.onSurface)
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(theme.onSurfaceVariant)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("統合先を選択")
                    } footer: {
                        Text("「\(source)」の全作品が選択した掲載誌に移動します")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("掲載誌を統合")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert(
                "掲載誌を統合しますか？",
                isPresented: Binding(
                    get: { pendingDestination != nil },
                    set: { if !$0 { pendingDestination = nil } }
                ),
                presenting: pendingDestination
            ) { destination in
                Button("統合する", role: .destructive) {
                    viewModel.mergePublisher(from: source, to: destination)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {
                    pendingDestination = nil
                }
            } message: { destination in
                let count = viewModel.mergePublisherPreviewCount(for: source)
                let iconNote = viewModel.publisherHasIcon(name: source)
                    ? "\n\n「\(source)」のアイコンも削除されます。"
                    : ""
                Text("「\(source)」の \(count) 件を「\(destination)」に統合します。\n\nこの操作は元に戻せません。\(iconNote)")
            }
        }
        .themedNavigationStyle()
    }
}
