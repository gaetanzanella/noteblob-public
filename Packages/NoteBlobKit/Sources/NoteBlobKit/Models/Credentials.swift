import Foundation

public struct Credentials: Sendable, Codable {
    public let token: String
    public let login: String

    public init(token: String, login: String) {
        self.token = token
        self.login = login
    }
}
