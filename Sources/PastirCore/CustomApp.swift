import Foundation

public struct CustomApp: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var command: String
    public var iconPath: String?
    public var symbol: String?

    public init(id: UUID = UUID(), name: String, command: String,
                iconPath: String? = nil, symbol: String? = nil) {
        self.id = id
        self.name = name
        self.command = command
        self.iconPath = iconPath
        self.symbol = symbol
    }
}
