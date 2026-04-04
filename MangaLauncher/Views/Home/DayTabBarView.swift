import SwiftUI
import PlatformKit

struct DayTabBarView: View {
    var viewModel: MangaViewModel
    var paging: PagingState
    var edit: EditState
    @Binding var selectedPublisher: String?
    let hasWallpaper: Bool
    let orderedDays: [DayOfWeek]
    let tabUnderline: Namespace.ID

    @State private var dropTargetDay: DayOfWeek?

    var body: some View {
        let currentDay = paging.currentDay
        HStack(spacing: 2) {
            ForEach(orderedDays) { day in
                Button {
                    paging.isAnimatingPageChange = true
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        paging.pageIndex = paging.pageIndexForDay(day)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.tabTransition) {
                        viewModel.selectedDay = day
                        selectedPublisher = nil
                        paging.isAnimatingPageChange = false
                    }
                } label: {
                    let isSelected = currentDay == day
                    let hasUnread = !day.isHiatus && !day.isCompleted && viewModel.unreadCount(for: day) > 0
                    VStack(spacing: 2) {
                        Text(day.shortName)
                            .font(.system(size: isSelected ? 26 : 18, weight: .black))
                            .foregroundStyle(
                                isSelected
                                    ? InkTheme.secondary
                                    : !day.isHiatus && !day.isCompleted && day == .today
                                        ? InkTheme.primary
                                        : (day.isHiatus || day.isCompleted)
                                            ? InkTheme.onSurfaceVariant.opacity(0.5)
                                            : InkTheme.onSurfaceVariant
                            )
                            .rotationEffect(.degrees(isSelected ? -3 : 0))
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)

                        if hasUnread {
                            Circle()
                                .fill(InkTheme.primary)
                                .frame(width: 6, height: 6)
                        } else {
                            Color.clear.frame(width: 6, height: 6)
                        }

                        if isSelected {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(InkTheme.secondary)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "tabUnderline", in: tabUnderline)
                        } else {
                            Color.clear.frame(height: 3)
                        }
                    }
                    .frame(height: 52)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: InkTheme.cornerRadius)
                        .fill(dropTargetDay == day ? InkTheme.secondary.opacity(0.2) : .clear)
                )
                .onDrop(of: [.text], isTargeted: Binding(
                    get: { dropTargetDay == day },
                    set: { dropTargetDay = $0 ? day : nil }
                )) { providers in
                    dropTargetDay = nil
                    if let draggingID = edit.draggingEntryID,
                       let entry = viewModel.findEntry(by: draggingID) {
                        viewModel.moveEntryToDay(entry, to: day)
                        edit.draggingEntryID = nil
                        withAnimation(.easeInOut(duration: 0.3)) {
                            paging.pageIndex = paging.pageIndexForDay(day)
                        }
                        return true
                    }
                    guard let provider = providers.first else { return false }
                    provider.loadObject(ofClass: NSString.self) { string, _ in
                        DispatchQueue.main.async {
                            if let uuidString = string as? String,
                               let uuid = UUID(uuidString: uuidString),
                               let entry = viewModel.findEntry(by: uuid) {
                                viewModel.moveEntryToDay(entry, to: day)
                                edit.draggingEntryID = nil
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    paging.pageIndex = paging.pageIndexForDay(day)
                                }
                            }
                        }
                    }
                    return true
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.25), value: paging.pageIndex)
    }
}
