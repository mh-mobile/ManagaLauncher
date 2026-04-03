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
        HStack(spacing: 0) {
            ForEach(orderedDays) { day in
                Button {
                    paging.isAnimatingPageChange = true
                    withAnimation(.easeInOut(duration: 0.3)) {
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
                    VStack(spacing: 4) {
                        Text(day.shortName)
                            .font(.headline)
                            .foregroundStyle(
                                !day.isHiatus && !day.isCompleted && day == .today
                                    ? .white
                                    : (hasWallpaper && isSelected)
                                        ? .white
                                        : isSelected
                                            ? Color.accentColor
                                            : (day.isHiatus || day.isCompleted) ? .secondary : .primary
                            )
                            .frame(width: 32, height: 32)
                            .background {
                                if !day.isHiatus && !day.isCompleted && day == .today {
                                    Circle()
                                        .fill(Color.accentColor)
                                } else if hasWallpaper && isSelected {
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                }
                            }
                        Circle()
                            .fill(hasUnread ? Color.accentColor : .clear)
                            .frame(width: 5, height: 5)
                        if isSelected {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "tabUnderline", in: tabUnderline)
                        } else {
                            Color.clear
                                .frame(height: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dropTargetDay == day ? Color.accentColor.opacity(0.3) : .clear)
                        .padding(.horizontal, 2)
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
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.25), value: paging.pageIndex)
    }
}
