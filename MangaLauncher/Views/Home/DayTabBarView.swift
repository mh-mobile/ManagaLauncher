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

    var body: some View {
        let currentDay = paging.currentDay
        HStack(spacing: theme.tabSpacing) {
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
                    VStack(spacing: theme.tabItemSpacing) {
                        Text(day.shortName)
                            .font(theme.tabFont(isSelected))
                            .foregroundStyle(tabTextColor(day: day, isSelected: isSelected))
                            .frame(width: theme.tabShowsTodayCircle ? 32 : nil,
                                   height: theme.tabShowsTodayCircle ? 32 : nil)
                            .background {
                                if theme.tabShowsTodayCircle {
                                    if !day.isHiatus && !day.isCompleted && day == .today {
                                        Circle().fill(theme.usesCustomSurface ? theme.primary : Color.accentColor)
                                    } else if hasWallpaper && isSelected {
                                        Circle().fill(Color.black.opacity(0.3))
                                    }
                                }
                            }
                            .rotationEffect(.degrees(isSelected ? theme.tabSelectedRotation : 0))
                            .scaleEffect(isSelected ? theme.tabSelectedScale : 1.0)
                        Circle()
                            .fill(hasUnread ? theme.primary : .clear)
                            .frame(width: theme.tabUnreadDotSize, height: theme.tabUnreadDotSize)
                        if isSelected {
                            RoundedRectangle(cornerRadius: theme.tabUnderlineCornerRadius)
                                .fill(theme.secondary)
                                .frame(height: theme.tabUnderlineHeight)
                                .matchedGeometryEffect(id: "tabUnderline", in: tabUnderline)
                        } else {
                            Color.clear.frame(height: theme.tabUnderlineHeight)
                        }
                    }
                    .frame(height: theme.tabItemHeight)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .fill(dropTargetDay == day ? theme.secondary.opacity(0.3) : .clear)
                        .padding(.horizontal, theme.tabShowsTodayCircle ? 2 : 0)
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
        .padding(.top, theme.tabShowsTodayCircle ? 4 : 0)
        .padding(.vertical, theme.tabShowsTodayCircle ? 0 : 6)
        .animation(.easeInOut(duration: 0.25), value: paging.pageIndex)
    }

    private func tabTextColor(day: DayOfWeek, isSelected: Bool) -> Color {
        if theme.forceDarkMode {
            if isSelected { return theme.secondary }
            if !day.isHiatus && !day.isCompleted && day == .today { return theme.primary }
            if day.isHiatus || day.isCompleted { return theme.onSurfaceVariant.opacity(0.5) }
            return theme.onSurfaceVariant
        } else if theme.usesCustomSurface {
            if isSelected { return theme.primary }
            if hasWallpaper && isSelected { return .white }
            if day.isHiatus || day.isCompleted { return theme.onSurfaceVariant.opacity(0.5) }
            return theme.onSurface
        } else {
            if !day.isHiatus && !day.isCompleted && day == .today { return .white }
            if hasWallpaper && isSelected { return .white }
            if isSelected { return Color.accentColor }
            if day.isHiatus || day.isCompleted { return .secondary }
            return .primary
        }
    }
}
