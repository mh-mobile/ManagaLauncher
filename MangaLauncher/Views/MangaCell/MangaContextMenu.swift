import SwiftUI

struct MangaContextMenu: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    var onReorder: (() -> Void)? = nil

    var body: some View {
        // 既読/未読トグルの表示条件:
        //  - 休載中: isRead が常に true 扱いなので未読トグル不要
        //  - 読了 (archived): 常に既読扱い、専用の「読了を取り消す」ボタンから戻す
        //  - 積読 (backlog): 表示する（ラベルを「今日読んだ」に変更して文脈を明示）
        //  - 完結: 表示する（一度読んだら既読据え置きだが、最初の一読は必要）
        if entry.publicationStatus != .hiatus && entry.readingState != .archived {
            Button {
                if entry.isRead {
                    viewModel.markAsUnread(entry)
                } else {
                    viewModel.markAsRead(entry)
                }
            } label: {
                if entry.readingState == .backlog {
                    Label(entry.isRead ? "今日読んだを取り消す" : "今日読んだ",
                          systemImage: entry.isRead ? "arrow.uturn.backward" : "checkmark")
                } else {
                    Label(entry.isRead ? "未読にする" : "既読にする",
                          systemImage: entry.isRead ? "envelope.badge" : "envelope.open")
                }
            }
        }

        Button {
            editingEntry = entry
        } label: {
            Label("編集", systemImage: "pencil")
        }

        Button {
            commentingEntry = entry
        } label: {
            Label("コメント", systemImage: "bubble.left.and.bubble.right")
        }

        if let onReorder {
            Button {
                onReorder()
            } label: {
                Label("並び替え", systemImage: "arrow.up.arrow.down")
            }
        }

        // 積読 → 追っかけ中（追いついた）
        if entry.readingState == .backlog {
            Button {
                viewModel.setReadingState(entry, to: .following)
            } label: {
                Label("追いついた", systemImage: "checkmark.circle")
            }
        }

        // 掲載状況の変更（読み切り・読了は対象外）
        if !entry.isOneShot && entry.readingState != .archived {
            if entry.publicationStatus != .active {
                Button {
                    viewModel.setPublicationStatus(entry, to: .active)
                } label: {
                    Label("連載に戻す", systemImage: "arrow.uturn.left")
                }
            }
            if entry.publicationStatus != .hiatus {
                Button {
                    viewModel.setPublicationStatus(entry, to: .hiatus)
                } label: {
                    Label("休載中にする", systemImage: "moon.zzz")
                }
            }
            if entry.publicationStatus != .finished {
                Button {
                    viewModel.setPublicationStatus(entry, to: .finished)
                } label: {
                    Label("完結にする", systemImage: "flag.checkered")
                }
            }
        }

        // 読了 ↔ 戻す
        Button {
            let newState: ReadingState = entry.readingState == .archived ? .following : .archived
            viewModel.setReadingState(entry, to: newState)
        } label: {
            Label(entry.readingState == .archived ? "読了を取り消す" : "読了にする",
                  systemImage: entry.readingState == .archived ? "arrow.uturn.left" : "checkmark.seal")
        }

        Button(role: .destructive) {
            viewModel.queueDelete(entry)
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}
