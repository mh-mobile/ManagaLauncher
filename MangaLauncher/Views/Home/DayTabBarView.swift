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

    private var theme: ThemeStyle { ThemeManager.shared.style }
    private var isInk: Bool { ThemeManager.shared.mode == .ink }

    var body: some View {
        let currentDay = paging.currentDay
        HStack(spacing: isInk ? 2 : 0) {
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
                    VStack(spacing: isInk ? 2 : 4) {
                        Text(day.shortName)
                            .font(isInk ? .system(size: isSelected ? 26 : 18, weight: .black) : .headline)
                            .foregroundStyle(tabTextColor(day: day, isSelected: isSelected))
                            .frame(width: isInk ? nil : 32, height: isInk ? nil : 32)
                            .background {
                                if !isInk {
                                    if !day.isHiatus && !day.isCompleted && day == .today {
                                        Circle().fill(Color.accentColor)
                                    } else if hasWallpaper && isSelected {
                                        Circle().fill(Color.black.opacity(0.3))
                                    }
                                }
                            }
                            .rotationEffect(.degrees(isInk && isSelected ? -3 : 0))
                            .scaleEffect(isInk && isSelected ? 1.1 : 1.0)
                        Circle()
                            .fill(hasUnread ? (isInk ? theme.primary : Color.accentColor) : .clear)
                            .frame(width: isInk ? 6 : 5, height: isInk ? 6 : 5)
                        if isSelected {
                            RoundedRectangle(cornerRadius: isInk ? 2 : 0)
                                .fill(isInk ? theme.secondary : Color.accentColor)
                                .frame(height: isInk ? 3 : 2)
                                .matchedGeometryEffect(id: "tabUnderline", in: tabUnderline)
                        } else {
                            Color.clear.frame(height: isInk ? 3 : 2)
                        }
                    }
                    .frame(height: isInk ? 52 : nil)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: isInk ? theme.cornerRadius : 8)
                        .fill(dropTargetDay == day ? (isInk ? theme.secondary : Color.accentColor).opacity(0.3) : .clear)
                        .padding(.horizontal, isInk ? 0 : 2)
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
        .padding(.top, isInk ? 0 : 4)
        .padding(.vertical, isInk ? 6 : 0)
        .animation(.easeInOut(duration: 0.25), value: paging.pageIndex)
    }

    private func tabTextColor(day: DayOfWeek, isSelected: Bool) -> Color {
        if isInk {
            if isSelected { return theme.secondary }
            if !day.isHiatus && !day.isCompleted && day == .today { return theme.primary }
            if day.isHiatus || day.isCompleted { return theme.onSurfaceVariant.opacity(0.5) }
            return theme.onSurfaceVariant
        } else {
            if !day.isHiatus && !day.isCompleted && day == .today { return .white }
            if hasWallpaper && isSelected { return .white }
            if isSelected { return Color.accentColor }
            if day.isHiatus || day.isCompleted { return .secondary }
            return .primary
        }
    }
}
