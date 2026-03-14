import SwiftUI
import SwiftData

@main
struct MangaLauncherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MangaEntry.self)
    }
}
