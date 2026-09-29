import Foundation

public struct Project: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
    public var sessionName: String { "projectbar-" + id.uuidString.lowercased() }
    public var terminalMarker: String { "[\(id.uuidString.prefix(8))]" }
    public var terminalTitle: String { "Pastir: \(name) \(terminalMarker)" }

    public init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.path = url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
