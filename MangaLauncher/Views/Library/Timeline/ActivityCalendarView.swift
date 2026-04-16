import SwiftUI
import UIKit

/// アクティビティがあった日にドット装飾を出す月 grid カレンダー。
/// SwiftUI の DatePicker(.graphical) は装飾 API が無いため、
/// UIKit の UICalendarView を UIViewRepresentable で包んで使う。
struct ActivityCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    /// startOfDay に正規化されたアクティビティありの日付集合。
    let activeDays: Set<Date>

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.locale = Locale(identifier: "ja_JP")
        view.delegate = context.coordinator
        view.fontDesign = .default

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = dateComponents(from: selectedDate)
        view.selectionBehavior = selection

        // 最初に表示する月を選択日に合わせる
        view.visibleDateComponents = dateComponents(from: selectedDate)

        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.activeDays = activeDays

        // 外部から selectedDate が変わったときに選択状態を同期
        if let selection = uiView.selectionBehavior as? UICalendarSelectionSingleDate {
            let current = dateComponents(from: selectedDate)
            if selection.selectedDate != current {
                selection.selectedDate = current
            }
        }

        // ドット装飾を再評価 (activeDays 更新後や月切替時の抜けを埋める)
        uiView.reloadDecorations(forDateComponents: [], animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDate: $selectedDate, activeDays: activeDays)
    }

    private func dateComponents(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: date)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        @Binding var selectedDate: Date
        var activeDays: Set<Date>

        init(selectedDate: Binding<Date>, activeDays: Set<Date>) {
            self._selectedDate = selectedDate
            self.activeDays = activeDays
        }

        func calendarView(
            _ calendarView: UICalendarView,
            decorationFor dateComponents: DateComponents
        ) -> UICalendarView.Decoration? {
            guard let date = Calendar.current.date(from: dateComponents) else { return nil }
            let day = Calendar.current.startOfDay(for: date)
            guard activeDays.contains(day) else { return nil }
            return .default(color: .tintColor, size: .small)
        }

        func dateSelection(
            _ selection: UICalendarSelectionSingleDate,
            didSelectDate dateComponents: DateComponents?
        ) {
            guard let components = dateComponents,
                  let date = Calendar.current.date(from: components) else { return }
            selectedDate = Calendar.current.startOfDay(for: date)
        }
    }
}
