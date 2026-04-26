import Foundation

public struct Repository: Sendable, Codable, Hashable {
    public let owner: String
    public let name: String

    public init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }
}
