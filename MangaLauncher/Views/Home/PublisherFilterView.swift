import SwiftUI

struct PublisherFilterView: View {
    let publishers: [String]
    @Binding var selectedPublisher: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "すべて", isSelected: selectedPublisher == nil) {
                    withAnimation { selectedPublisher = nil }
                }
                ForEach(publishers, id: \.self) { pub in
                    FilterChip(label: pub, isSelected: selectedPublisher == pub) {
                        withAnimation { selectedPublisher = selectedPublisher == pub ? nil : pub }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}
