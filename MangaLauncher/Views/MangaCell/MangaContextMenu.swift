import SwiftUI

struct MangaContextMenu: View {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    @Binding var editingEntry: MangaEntry?
    @Binding var commentingEntry: MangaEntry?
    var links: [MangaLink] = []
    var onShowLifetime: (() -> Void)? = nil
    var onRecordSpecialEpisode: (() -> Void)? = nil
    var onReorder: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        // MARK: 既読/未読トグル
        //  - 休載中: isRead が常に true 扱いなので未読トグル不要
        //  - 読了 (archived): 常に既読扱い。戻すには「状態を変更」から「追っかけ中にする」
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
            viewModel.incrementEpisode(entry)
        } label: {
            Label(
                entry.currentEpisode == nil ? "話数を記録（1話）" : "\((entry.currentEpisode ?? 0) + 1)話まで読んだ",
                systemImage: "plus.circle"
            )
        }

        if let onRecordSpecialEpisode {
            Button {
                onRecordSpecialEpisode()
            } label: {
                Label("特別回を記録", systemImage: "pencil.and.list.clipboard")
            }
        }

        // MARK: フォーカス積読
        // 積読 (backlog) の中から最大 3 本だけ「今集中して消化する」と宣言する。
        // ライブラリ最上部に常時表示されるので選択疲労が軽減される。
        if entry.readingState == .backlog {
            Button {
                if entry.isFocused {
                    viewModel.unfocus(entry)
                } else {
                    viewModel.focus(entry)
                }
            } label: {
                if entry.isFocused {
                    Label("フォーカスを外す", systemImage: "pin.slash")
                } else {
                    Label("フォーカスする", systemImage: "pin")
                }
            }
            .disabled(!entry.isFocused && !viewModel.canFocus())
        }

        Divider()

        // MARK: 日常操作
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

        // MARK: 関連リンク
        if !links.isEmpty {
            Menu {
                ForEach(links) { link in
                    Button {
                        if let url = URL(string: link.url) {
                            openURL(url)
                        }
                    } label: {
                        Label(
                            link.title.isEmpty ? link.linkType.displayName : link.title,
                            systemImage: link.linkType.iconName
                        )
                    }
                }
            } label: {
                Label("関連リンク", systemImage: "link")
            }
        }

        if let onShowLifetime {
            Button {
                onShowLifetime()
            } label: {
                Label("ライフタイムを見る", systemImage: "chart.bar.xaxis")
            }
        }

        if let onReorder {
            Button {
                onReorder()
            } label: {
                Label("並び替え", systemImage: "arrow.up.arrow.down")
            }
        }

        Divider()

        // MARK: 状態変更（サブメニュー）
        // 現在の状態から遷移可能な選択肢のみを表示する。
        // 「取り消す」のような曖昧なトグルを持たず、ユーザーが行き先を明示する。
        Menu {
            // 読書状況の遷移
            if entry.readingState != .following {
                Button {
                    viewModel.setReadingState(entry, to: .following)
                } label: {
                    Label("追っかけ中にする", systemImage: "eyes")
                }
            }
            // 読み切りは invariant 上 backlog 不可
            if !entry.isOneShot && entry.readingState != .backlog {
                Button {
                    viewModel.setReadingState(entry, to: .backlog)
                } label: {
                    Label("積読にする", systemImage: "books.vertical")
                }
            }
            if entry.readingState != .archived {
                Button {
                    viewModel.setReadingState(entry, to: .archived)
                } label: {
                    Label("読了にする", systemImage: "checkmark.seal")
                }
            }

            // 掲載状況の遷移（読み切り・読了は対象外）
            if !entry.isOneShot && entry.readingState != .archived {
                if entry.publicationStatus != .active {
                    Button {
                        viewModel.setPublicationStatus(entry, to: .active)
                    } label: {
                        Label("連載中にする", systemImage: "book")
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
        } label: {
            Label("状態を変更", systemImage: "slider.horizontal.3")
        }

        Divider()

        Button {
            if entry.isHidden {
                viewModel.setHidden(entry, isHidden: false)
            } else {
                viewModel.setHidden(entry, isHidden: true)
            }
        } label: {
            Label(entry.isHidden ? "非表示を解除" : "非表示にする",
                  systemImage: entry.isHidden ? "eye" : "eye.slash")
        }

        Button(role: .destructive) {
            viewModel.queueDelete(entry)
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}
