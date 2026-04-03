import SwiftUI
import PlatformKit

struct WiggleModifier: ViewModifier {
    let isActive: Bool
    @State private var isWiggling = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isActive ? (isWiggling ? 2 : -2) : 0))
            .animation(
                isActive
                    ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.15),
                value: isActive ? isWiggling : false
            )
            .onChange(of: isActive) { _, active in
                isWiggling = active
            }
            .onAppear {
                isWiggling = isActive
            }
    }
}

struct GridDropDelegate: DropDelegate {
    let entry: MangaEntry
    let entries: [MangaEntry]
    let day: DayOfWeek
    @Binding var draggingEntryID: UUID?
    let viewModel: MangaViewModel

    func performDrop(info: DropInfo) -> Bool {
        draggingEntryID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingEntryID,
              draggingID != entry.id else { return }

        if !entries.contains(where: { $0.id == draggingID }),
           let draggedEntry = viewModel.findEntry(by: draggingID) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.moveEntryToDay(draggedEntry, to: day, at: entry)
            }
            return
        }

        guard let fromIndex = entries.firstIndex(where: { $0.id == draggingID }),
              let toIndex = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.moveEntries(
                for: day,
                from: IndexSet(integer: fromIndex),
                to: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct EmptyPageDropDelegate: DropDelegate {
    let day: DayOfWeek
    @Binding var draggingEntryID: UUID?
    let viewModel: MangaViewModel

    func performDrop(info: DropInfo) -> Bool {
        if let draggingID = draggingEntryID,
           let draggedEntry = viewModel.findEntry(by: draggingID),
           draggedEntry.dayOfWeek != day {
            viewModel.moveEntryToDay(draggedEntry, to: day)
        }
        draggingEntryID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.platformGray5)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
