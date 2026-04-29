import SwiftUI

/// 関連リンクの追加・編集シート
struct EditLinkView: View {
    @Environment(\.dismiss) private var dismiss

    var viewModel: MangaViewModel
    let entry: MangaEntry
    var link: MangaLink?

    @State private var linkType: LinkType = .other
    @State private var title: String = ""
    @State private var url: String = ""
    @State private var didLoad = false

    private var theme: ThemeStyle { ThemeManager.shared.style }

    private var isEditing: Bool { link != nil }

    private static let allowedSchemes: Set<String> = ["https", "http"]

    private var isValidURL: Bool {
        guard let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased() else { return false }
        return Self.allowedSchemes.contains(scheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("リンク種別") {
                    Picker("種別", selection: $linkType) {
                        ForEach(LinkType.allCases) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                }

                Section("リンク情報") {
                    TextField("タイトル（任意）", text: $title)
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("URL", text: $url)
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .onChange(of: url) { _, newValue in
                            if !isEditing && linkType == .other {
                                let detected = LinkType.detect(from: newValue)
                                if detected != .other {
                                    linkType = detected
                                }
                            }
                        }
                    if !url.isEmpty && !isValidURL {
                        Text("有効なURLを入力してください（例: https://...）")
                            .font(theme.captionFont)
                            .foregroundStyle(theme.error)
                    }
                }
            }
            .themedNavigationStyle()
            .navigationTitle(isEditing ? "リンクを編集" : "リンクを追加")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .if(theme.forceDarkMode) { view in
                        view.foregroundStyle(theme.onSurfaceVariant)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveLink()
                        dismiss()
                    }
                    .disabled(url.isEmpty || !isValidURL)
                    .if(theme.forceDarkMode) { view in
                        view.foregroundStyle(theme.primary)
                    }
                }
            }
            .onAppear { loadLinkIfNeeded() }
        }
    }

    private func loadLinkIfNeeded() {
        guard !didLoad else { return }
        if let link {
            linkType = link.linkType
            title = link.title
            url = link.url
        }
        didLoad = true
    }

    private func saveLink() {
        if let link {
            viewModel.updateLink(link, linkType: linkType, title: title, url: url)
        } else {
            viewModel.addLink(entry, linkType: linkType, title: title, url: url)
        }
    }
}
