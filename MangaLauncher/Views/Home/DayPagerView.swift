import SwiftUI

struct DayPagerView<PageContent: View>: View {
    @Bindable var paging: PagingState
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    @Binding var selectedPublisher: String?
    var viewModel: MangaViewModel
    let pageContent: (DayOfWeek, MangaViewModel) -> PageContent

    private var dayCount: Int { DayOfWeek.orderedDays.count }
    private var totalPages: Int { dayCount + 2 } // +2 for wraparound

    var body: some View {
        #if os(iOS) || os(visionOS)
        TabView(selection: $paging.pageIndex) {
            ForEach(0..<totalPages, id: \.self) { index in
                pageContent(paging.dayForPageIndex(index), viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: paging.pageIndex) { _, newValue in
            let day = paging.dayForPageIndex(newValue)
            if !paging.isAnimatingPageChange {
                viewModel.selectedDay = day
                listEditMode = .inactive
                selectedPublisher = nil
            }

            // Wraparound: page 0 → last real page, page (count+1) → first real page
            if newValue == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.pageLoop) {
                    withAnimation(.none) {
                        paging.pageIndex = dayCount
                    }
                }
            } else if newValue == dayCount + 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.pageLoop) {
                    withAnimation(.none) {
                        paging.pageIndex = 1
                    }
                }
            }
        }
        #else
        pageContent(viewModel.selectedDay, viewModel)
        #endif
    }
}
