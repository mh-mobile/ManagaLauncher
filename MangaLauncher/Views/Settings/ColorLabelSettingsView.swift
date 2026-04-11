import SwiftUI

struct ColorLabelSettingsView: View {
    @State private var labels: [String: String] = [:]
    @FocusState private var focusedColor: String?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Form {
            Section {
                ForEach(MangaColor.all) { mangaColor in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(mangaColor.color)
                            .frame(width: 28, height: 28)
                        Text(mangaColor.displayName)
                            .frame(width: 60, alignment: .leading)
                            .foregroundStyle(theme.onSurface)
                        TextField("ラベル（任意）", text: Binding(
                            get: { labels[mangaColor.name] ?? "" },
                            set: { labels[mangaColor.name] = $0 }
                        ))
                        .focused($focusedColor, equals: mangaColor.name)
                        .submitLabel(.done)
                        .onSubmit {
                            saveLabel(for: mangaColor.name)
                        }
                    }
                }
            } footer: {
                Text("ラベルを設定すると、検索画面のカラーフィルターで「お気に入り」「新刊」などの名前で絞り込めるようになります。")
            }
        }
        .themedNavigationStyle()
        .navigationTitle("カラーラベル")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            ColorLabelStore.shared.load()
            labels = ColorLabelStore.shared.labels
        }
        .onDisappear {
            // 全てのラベルを保存
            for (color, label) in labels {
                ColorLabelStore.shared.setLabel(label, for: color)
            }
            // 削除されたラベル（textが空）も反映
            for color in MangaColor.all where labels[color.name] == nil || labels[color.name]?.isEmpty == true {
                ColorLabelStore.shared.setLabel("", for: color.name)
            }
        }
    }

    private func saveLabel(for colorName: String) {
        let label = labels[colorName] ?? ""
        ColorLabelStore.shared.setLabel(label, for: colorName)
        focusedColor = nil
    }
}
