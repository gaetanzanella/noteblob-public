import Foundation

public protocol CredentialsProvider: Sendable {
    func loadCredentials() throws -> Credentials?
}
