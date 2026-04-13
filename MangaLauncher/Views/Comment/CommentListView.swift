import SwiftUI

struct CommentListView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: MangaEntry
    var viewModel: MangaViewModel

    @State private var draft: String = ""
    @State private var editingComment: MangaComment?
    @State private var editingContent: String = ""
    @State private var pendingDeleteComment: MangaComment?
    @FocusState private var composerFocused: Bool

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        NavigationStack {
            let _ = viewModel.refreshCounter
            let comments = viewModel.fetchComments(for: entry)

            ZStack {
                if theme.usesCustomSurface {
                    theme.surface.ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    if comments.isEmpty {
                        ContentUnavailableView {
                            Label("コメントがありません", systemImage: "bubble.left.and.bubble.right")
                                .foregroundStyle(theme.onSurfaceVariant)
                        } description: {
                            Text("感想や話ごとのメモを下から投稿できます")
                                .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(comments, id: \.id) { comment in
                                commentRow(comment)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    composer
                }
            }
            .navigationTitle(entry.name)
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $editingComment) { comment in
                editSheet(for: comment)
            }
            .confirmationDialog(
                "このコメントを削除しますか？",
                isPresented: Binding(
                    get: { pendingDeleteComment != nil },
                    set: { if !$0 { pendingDeleteComment = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeleteComment
            ) { comment in
                Button("削除", role: .destructive) {
                    viewModel.deleteComment(comment)
                    pendingDeleteComment = nil
                }
                Button("キャンセル", role: .cancel) {
                    pendingDeleteComment = nil
                }
            } message: { _ in
                Text("この操作は取り消せません。")
            }
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: MangaComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(comment.content)
                .font(theme.bodyFont)
                .foregroundStyle(theme.onSurface)
                .textSelection(.enabled)
            HStack(spacing: 6) {
                Text(comment.createdAt.formatted(.dateTime.year().month().day().hour().minute()))
                if comment.updatedAt != nil {
                    Text("· 編集済み")
                }
            }
            .font(theme.caption2Font)
            .foregroundStyle(theme.onSurfaceVariant)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeleteComment = comment
            } label: {
                Label("削除", systemImage: "trash")
            }
            Button {
                editingContent = comment.content
                editingComment = comment
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(theme.primary)
        }
    }

    @ViewBuilder
    private var composer: some View {
        Divider()
        HStack(alignment: .bottom, spacing: 8) {
            TextField("コメントを書く…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(10)
                .background(theme.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))
                #if os(iOS) || os(visionOS)
                .textInputAutocapitalization(.none)
                #endif
            Button {
                viewModel.addComment(entry, content: draft)
                draft = ""
                composerFocused = false
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(canSubmit ? theme.primary : theme.onSurfaceVariant.opacity(0.4))
            }
            .disabled(!canSubmit)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func editSheet(for comment: MangaComment) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("コメント", text: $editingContent, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .navigationTitle("コメントを編集")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { editingComment = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        viewModel.updateComment(comment, content: editingContent)
                        editingComment = nil
                    }
                    .disabled(editingContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
