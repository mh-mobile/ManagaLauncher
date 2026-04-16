import SwiftUI
import AppIntents

/// 設定画面の「ショートカット」セクション。
/// ShortcutsLink のラベルは CFBundleName 固定で変更不可のため、
/// ZStack で上に自前ラベルを重ね、下の ShortcutsLink がタップを受ける workaround。
struct ShortcutsSection: View {
    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""
    }

    var body: some View {
        Section {
            ZStack {
                ShortcutsLink()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .opacity(0.01)
                HStack(spacing: 10) {
                    Image(systemName: "square.2.layers.3d.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.30, blue: 0.60),
                                    Color(red: 0.55, green: 0.35, blue: 0.95),
                                    Color(red: 0.25, green: 0.55, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Text("\(appDisplayName)のショートカット")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)
            }
            // VoiceOver: ShortcutsLink 内蔵の英語ラベルではなく自前の日本語を読ませる
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(appDisplayName)のショートカット")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("ショートカットアプリを開きます")
        } header: {
            Text("ショートカット")
        } footer: {
            Text("ショートカットアプリからマンガの登録や曜日の切替をオートメーション化できます。")
        }
    }
}
