import Foundation

struct PendingShareData: Codable, Identifiable {
    let id: UUID
    var name: String
    var url: String
    var publisher: String
    var dayOfWeek: Int
    var imageData: Data?
    let createdAt: Date

    init(name: String = "", url: String = "", publisher: String = "", dayOfWeek: Int = DayOfWeek.today.rawValue, imageData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.publisher = publisher
        self.dayOfWeek = dayOfWeek
        self.imageData = imageData
        self.createdAt = Date()
    }

    static var pendingDirectory: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupIdentifier
        )!
        return container.appendingPathComponent("pending_shares", isDirectory: true)
    }

    func save() throws {
        let dir = Self.pendingDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: fileURL)
    }

    static func load(id: UUID) -> PendingShareData? {
        let fileURL = pendingDirectory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PendingShareData.self, from: data)
    }

    static func delete(id: UUID) {
        let fileURL = pendingDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
}
