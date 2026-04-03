import SwiftUI

struct DayPagerView<PageContent: View>: View {
    @Binding var pageIndex: Int
    @Binding var isAnimatingPageChange: Bool
    #if os(iOS) || os(visionOS)
    @Binding var listEditMode: EditMode
    #endif
    @Binding var selectedPublisher: String?
    var viewModel: MangaViewModel
    let pageContent: (DayOfWeek, MangaViewModel) -> PageContent

    private let orderedDays = DayOfWeek.orderedCases

    var body: some View {
        #if os(iOS) || os(visionOS)
        TabView(selection: $pageIndex) {
            ForEach(0..<11, id: \.self) { index in
                pageContent(dayForPageIndex(index), viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { oldValue, newValue in
            let day = dayForPageIndex(newValue)
            if !isAnimatingPageChange {
                viewModel.selectedDay = day
                listEditMode = .inactive
                selectedPublisher = nil
            }

            if newValue == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.none) {
                        pageIndex = 9
                    }
                }
            } else if newValue == 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.none) {
                        pageIndex = 1
                    }
                }
            }
        }
        #else
        pageContent(viewModel.selectedDay, viewModel)
        #endif
    }

    // MARK: - Page Index Helpers

    func dayForPageIndex(_ index: Int) -> DayOfWeek {
        let clamped = ((index - 1) % 9 + 9) % 9
        return orderedDays[clamped]
    }

    static func pageIndexForDay(_ day: DayOfWeek) -> Int {
        let orderedDays = DayOfWeek.orderedCases
        guard let index = orderedDays.firstIndex(of: day) else { return 1 }
        return index + 1
    }
}
