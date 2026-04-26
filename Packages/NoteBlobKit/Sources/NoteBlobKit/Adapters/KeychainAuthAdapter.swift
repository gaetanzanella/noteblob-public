import Foundation
import Security

final class KeychainAuthAdapter: UserRepository, @unchecked Sendable {

    private let service: String
    private let account: String
    private let session: URLSession
    private let credentialsProvider: CredentialsProvider?

    init(
        session: URLSession = .shared,
        credentialsProvider: CredentialsProvider? = nil,
        service: String = "com.noteblob.auth",
        account: String = "github-token"
    ) {
        self.session = session
        self.credentialsProvider = credentialsProvider
        self.service = service
        self.account = account
    }

    // MARK: - Validate

    func validate(token: String) async throws -> User {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.invalidToken
        }

        let json = try JSONDecoder().decode(GitHubUser.self, from: data)
        return User(login: json.login, avatarURL: json.avatar_url)
    }

    // MARK: - Keychain

    func saveCredentials(_ credentials: Credentials) throws {
        try? deleteCredentials()
        let data = try JSONEncoder().encode(credentials)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError(status)
        }
    }

    func loadCredentials() throws -> Credentials? {
        if let credentials = try credentialsProvider?.loadCredentials() {
            return credentials
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status == errSecItemNotFound { return nil }
            throw AuthError.keychainError(status)
        }
        if let credentials = try? JSONDecoder().decode(Credentials.self, from: data) {
            return credentials
        }
        // Legacy migration: token-only keychain entry
        guard let token = String(data: data, encoding: .utf8) else { return nil }
        return nil
    }

    func deleteCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychainError(status)
        }
    }
}

// MARK: - Private

enum AuthError: Error, LocalizedError {
    case invalidToken
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidToken: return "Invalid GitHub token"
        case .keychainError(let status): return "Keychain error: \(status)"
        }
    }
}

private struct GitHubUser: Decodable {
    let login: String
    let avatar_url: String
}
