import SwiftUI

struct SpecialEpisodeAlertModifier: ViewModifier {
    let entry: MangaEntry
    var viewModel: MangaViewModel
    @Binding var isPresented: Bool
    @State private var text: String = ""

    func body(content: Content) -> some View {
        content
            .alert("特別回を記録", isPresented: $isPresented) {
                TextField("おまけ、1.5話 など", text: $text)
                Button("記録") {
                    if !text.isEmpty {
                        viewModel.recordSpecialEpisode(entry, label: text)
                        text = ""
                    }
                }
                Button("キャンセル", role: .cancel) {
                    text = ""
                }
            }
    }
}

extension View {
    func specialEpisodeAlert(entry: MangaEntry, viewModel: MangaViewModel, isPresented: Binding<Bool>) -> some View {
        modifier(SpecialEpisodeAlertModifier(entry: entry, viewModel: viewModel, isPresented: isPresented))
    }
}
