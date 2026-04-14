import SwiftUI
import PlatformKit

struct MangaColor: Identifiable, Hashable {
    let name: String
    let displayName: String

    var id: String { name }
    var color: Color { Color.fromName(name) }

    static let all: [MangaColor] = [
        MangaColor(name: "red", displayName: "赤"),
        MangaColor(name: "orange", displayName: "オレンジ"),
        MangaColor(name: "yellow", displayName: "黄"),
        MangaColor(name: "green", displayName: "緑"),
        MangaColor(name: "blue", displayName: "青"),
        MangaColor(name: "purple", displayName: "紫"),
        MangaColor(name: "pink", displayName: "ピンク"),
        MangaColor(name: "teal", displayName: "ティール"),
    ]

    static func displayName(for name: String) -> String {
        all.first { $0.name == name }?.displayName ?? name
    }
}

@Observable
final class ColorLabelStore {
    static let shared = ColorLabelStore()

    private let key = "colorLabels"
    private(set) var labels: [String: String] = [:]

    private init() {
        load()
    }

    func load() {
        labels = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    func setLabel(_ label: String, for colorName: String) {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            labels.removeValue(forKey: colorName)
        } else {
            labels[colorName] = trimmed
        }
        UserDefaults.standard.set(labels, forKey: key)
    }

    func label(for colorName: String) -> String? {
        labels[colorName]
    }
}
