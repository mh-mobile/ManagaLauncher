import SwiftUI

struct PublisherPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var publisher: String
    var viewModel: MangaViewModel

    @State private var newPublisher: String = ""

    private var existingPublishers: [String] {
        var pubs = Set(viewModel.allPublishers())
        if !publisher.isEmpty {
            pubs.insert(publisher)
        }
        return pubs.sorted()
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("新しい掲載誌を入力", text: $newPublisher)
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    if !newPublisher.isEmpty {
                        Button("追加") {
                            selectPublisher(newPublisher)
                        }
                        .bold()
                    }
                }
            }

            if !existingPublishers.isEmpty {
                Section("登録済みの掲載誌") {
                    ForEach(existingPublishers, id: \.self) { pub in
                        Button {
                            selectPublisher(pub)
                        } label: {
                            HStack {
                                Text(pub)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if publisher == pub {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }

            if !publisher.isEmpty {
                Section {
                    Button(role: .destructive) {
                        selectPublisher("")
                    } label: {
                        Text("掲載誌を解除")
                    }
                }
            }
        }
        .navigationTitle("掲載誌")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func selectPublisher(_ value: String) {
        publisher = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
        }
    }
}
