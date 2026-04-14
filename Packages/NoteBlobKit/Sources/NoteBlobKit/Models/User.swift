import Foundation

public struct User: Sendable, Hashable {
    public let login: String
    public let avatarURL: String

    public init(login: String, avatarURL: String) {
        self.login = login
        self.avatarURL = avatarURL
    }
}
