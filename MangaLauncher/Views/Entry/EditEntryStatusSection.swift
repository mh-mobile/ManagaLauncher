import SwiftUI

/// 編集画面の「種類 / 掲載状況 / 読書状況」3 セクション。
/// 連載/読み切り切替時の invariant 矯正もここで行う。
struct EditEntryStatusSection: View {
    @Binding var isOneShot: Bool
    @Binding var publicationStatus: PublicationStatus
    @Binding var readingState: ReadingState

    var body: some View {
        Group {
            Section("種類") {
                Picker("種類", selection: $isOneShot) {
                    Text("連載").tag(false)
                    Text("読み切り").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: isOneShot) { _, newValue in
                    if newValue {
                        publicationStatus = .active
                        if readingState == .backlog {
                            readingState = .following
                        }
                    }
                }
            }

            if !isOneShot {
                Section {
                    Picker("掲載状況", selection: $publicationStatus) {
                        ForEach(PublicationStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("掲載状況")
                } footer: {
                    Text("連載中はホーム画面に表示されます。休載中・完結はライブラリのみに表示されます。")
                }

                Section {
                    Picker("読書状況", selection: $readingState) {
                        ForEach(ReadingState.allCases) { state in
                            Text(state.displayName).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("読書状況")
                } footer: {
                    Text("追っかけ中はホーム画面に表示されます。積読・読了はライブラリのみに表示されます。読了にすると常に既読扱いになります。")
                }
            }
        }
    }
}
