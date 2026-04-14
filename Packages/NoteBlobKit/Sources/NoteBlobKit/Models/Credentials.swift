import Foundation

public struct Credentials: Sendable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}
