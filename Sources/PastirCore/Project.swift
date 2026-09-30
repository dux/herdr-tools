import Foundation

public struct Project: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }

    public init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.path = url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
