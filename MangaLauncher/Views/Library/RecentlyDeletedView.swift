import SwiftUI
import PlatformKit

struct RecentlyDeletedView: View {
    var viewModel: MangaViewModel
    @State private var isAuthenticated = false
    @State private var needsAuth = false
    @State private var entries: [MangaEntry] = []
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteConfirmation: MangaEntry?

    private var theme: ThemeStyle { ThemeManager.shared.style }

    var body: some View {
        Group {
            if needsAuth && !isAuthenticated {
                lockedView
            } else if entries.isEmpty {
                ContentUnavailableView {
                    Label("最近削除した項目はありません", systemImage: "trash")
                        .foregroundStyle(theme.onSurfaceVariant)
                } description: {
                    Text("削除したマンガは30日間ここに保管されます。\n30日後に自動的に完全削除されます。")
                        .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
                }
            } else {
                List {
                    ForEach(entries, id: \.id) { entry in
                        entryRow(entry)
                            .swipeActions(edge: .leading) {
                                Button {
                                    restore(entry)
                                } label: {
                                    Label("復元", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    showDeleteConfirmation = entry
                                } label: {
                                    Label("完全に削除", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    restore(entry)
                                } label: {
                                    Label("復元", systemImage: "arrow.uturn.backward")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    showDeleteConfirmation = entry
                                } label: {
                                    Label("完全に削除", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .themedNavigationStyle()
        .navigationTitle("最近削除した項目")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            restoreAll()
                        } label: {
                            Label("すべて復元", systemImage: "arrow.uturn.backward")
                        }
                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label("すべて削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadEntries()
        }
        .alert("完全に削除", isPresented: $showDeleteAllConfirmation) {
            Button("すべて削除", role: .destructive) {
                permanentlyDeleteAll()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(entries.count)件のマンガを完全に削除します。この操作は取り消せません。")
        }
        .alert("完全に削除", isPresented: Binding(
            get: { showDeleteConfirmation != nil },
            set: { if !$0 { showDeleteConfirmation = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let entry = showDeleteConfirmation {
                    permanentlyDelete(entry)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let entry = showDeleteConfirmation {
                Text("「\(entry.name)」を完全に削除します。この操作は取り消せません。")
            }
        }
    }

    @ViewBuilder
    private var lockedView: some View {
        ContentUnavailableView {
            Label("認証が必要です", systemImage: "lock.fill")
                .foregroundStyle(theme.onSurfaceVariant)
        } description: {
            Text("非表示のマンガが含まれているため認証が必要です")
                .foregroundStyle(theme.onSurfaceVariant.opacity(0.7))
        } actions: {
            Button("認証する") { authenticate() }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: MangaEntry) -> some View {
        HStack(spacing: 12) {
            if let data = entry.imageData, let image = data.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.fromName(entry.iconColor))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(entry.name.prefix(1))
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.onSurface)
                    if entry.isHidden {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(theme.onSurfaceVariant)
                    }
                }
                if !entry.publisher.isEmpty {
                    Text(entry.publisher)
                        .font(theme.captionFont)
                        .foregroundStyle(theme.onSurfaceVariant)
                }
            }
            Spacer()
            if let deletedAt = entry.deletedAt {
                Text(remainingDaysText(from: deletedAt))
                    .font(.caption2)
                    .foregroundStyle(theme.onSurfaceVariant)
            }
        }
    }

    private func loadEntries() {
        if viewModel.hasHiddenDeletedEntries() {
            needsAuth = true
            authenticate()
        } else {
            needsAuth = false
            entries = viewModel.deletedEntries()
        }
    }

    private func authenticate() {
        Task {
            let success = await BiometricAuthService.authenticate(
                reason: "削除した項目を表示するために認証が必要です"
            )
            isAuthenticated = success
            if success {
                entries = viewModel.deletedEntries()
            }
        }
    }

    private func remainingDaysText(from deletedAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        let remaining = max(0, 30 - days)
        return "あと\(remaining)日"
    }

    private func restore(_ entry: MangaEntry) {
        viewModel.restoreEntry(entry)
        withAnimation {
            entries.removeAll { $0.id == entry.id }
        }
    }

    private func permanentlyDelete(_ entry: MangaEntry) {
        viewModel.permanentlyDelete(entry)
        withAnimation {
            entries.removeAll { $0.id == entry.id }
        }
    }

    private func restoreAll() {
        viewModel.restoreEntries(entries)
        withAnimation {
            entries.removeAll()
        }
    }

    private func permanentlyDeleteAll() {
        viewModel.permanentlyDeleteEntries(entries)
        withAnimation {
            entries.removeAll()
        }
    }
}
