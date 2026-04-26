import Foundation

public final class AuthService: Sendable {

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    public func login(token: String) async throws -> User {
        let user = try await userRepository.validate(token: token)
        try userRepository.saveCredentials(Credentials(token: token, login: user.login))
        return user
    }

    public func logout() throws {
        try userRepository.deleteCredentials()
    }

    public var isAuthenticated: Bool {
        (try? userRepository.loadCredentials()) != nil
    }

    public var login: String? {
        try? userRepository.loadCredentials()?.login
    }
}
