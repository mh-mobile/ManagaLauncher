import SwiftUI

struct DayPagerView<PageContent: View>: View {
    @Bindable var paging: PagingState
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    @Binding var selectedPublisher: String?
    var viewModel: MangaViewModel
    let pageContent: (DayOfWeek, MangaViewModel) -> PageContent

    var body: some View {
        #if os(iOS) || os(visionOS)
        TabView(selection: $paging.pageIndex) {
            ForEach(0..<11, id: \.self) { index in
                pageContent(paging.dayForPageIndex(index), viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .if(ThemeManager.shared.style.usesCustomSurface) { view in
            view.background(ThemeManager.shared.style.surface)
        }
        .onChange(of: paging.pageIndex) { oldValue, newValue in
            let day = paging.dayForPageIndex(newValue)
            if !paging.isAnimatingPageChange {
                viewModel.selectedDay = day
                listEditMode = .inactive
                selectedPublisher = nil
            }

            if newValue == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.pageLoop) {
                    withAnimation(.none) {
                        paging.pageIndex = 9
                    }
                }
            } else if newValue == 10 {
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
