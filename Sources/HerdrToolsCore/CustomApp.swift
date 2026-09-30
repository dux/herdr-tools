import Foundation

public struct CustomApp: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var command: String
    public var symbol: String?

    public init(id: UUID = UUID(), name: String, command: String, symbol: String? = nil) {
        self.id = id
        self.name = name
        self.command = command
        self.symbol = symbol
    }
}
