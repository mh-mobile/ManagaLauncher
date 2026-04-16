import AppIntents

/// コントロールセンターから「マンガを登録」を起動するための intent。
/// アプリを開いて EditEntryView を立ち上げるだけのシグナルを出す。
/// AddMangaIntent と違いパラメータを取らない。
struct OpenAddEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "マンガを登録"
    static var description: IntentDescription = "マンガ曜日の新規登録画面を開きます"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // App 側 checkPendingIntent が空 dict を受け取るとデフォルト値で
        // EditEntryView を開くので、空 dict を設定するだけで十分。
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
        defaults?.set([String: String](), forKey: "pendingIntentData")
        return .result()
    }
}
