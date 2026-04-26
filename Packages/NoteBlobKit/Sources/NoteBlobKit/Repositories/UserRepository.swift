import Foundation

protocol UserRepository: Sendable {
    func validate(token: String) async throws -> User
    func saveCredentials(_ credentials: Credentials) throws
    func loadCredentials() throws -> Credentials?
    func deleteCredentials() throws
}
