import Foundation
import PastirCore

actor CustomAppFile {
    struct Snapshot: Codable, Sendable {
        var apps: [CustomApp] = []
    }

    private let url: URL

    init(url: URL) { self.url = url }

    func load() throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return Snapshot() }
        return try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
    }

    func save(_ snapshot: Snapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }
}
