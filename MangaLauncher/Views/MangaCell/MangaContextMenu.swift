import SwiftUI

struct MangaContextMenu: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    var onReorder: () -> Void

    var body: some View {
        if !entry.isOnHiatus {
            Button {
                if entry.isRead {
                    viewModel.markAsUnread(entry)
                } else {
                    viewModel.markAsRead(entry)
                }
            } label: {
                Label(entry.isRead ? "未読にする" : "既読にする",
                      systemImage: entry.isRead ? "envelope.badge" : "envelope.open")
            }
        }
        Button {
            editingEntry = entry
        } label: {
            Label("編集", systemImage: "pencil")
        }
        Button {
            onReorder()
        } label: {
            Label("並び替え", systemImage: "arrow.up.arrow.down")
        }
        Button {
            viewModel.toggleHiatus(entry)
        } label: {
            Label(entry.isOnHiatus ? "連載に戻す" : "休載中にする",
                  systemImage: entry.isOnHiatus ? "arrow.uturn.left" : "moon.zzz")
        }
        Button {
            viewModel.toggleCompleted(entry)
        } label: {
            Label(entry.isCompleted ? "連載に戻す" : "完結にする",
                  systemImage: entry.isCompleted ? "arrow.uturn.left" : "checkmark.seal")
        }
        Button(role: .destructive) {
            viewModel.queueDelete(entry)
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}
