import Foundation
import Testing

@testable import NoteBlobKit

struct KeychainAuthAdapterTests {

    private let testService = "com.noteblob.auth.tests-\(UUID().uuidString)"
    private let testAccount = "github-token-test"

    private func makeAdapter() -> KeychainAuthAdapter {
        KeychainAuthAdapter(service: testService, account: testAccount)
    }

    private func cleanup(_ adapter: KeychainAuthAdapter) {
        try? adapter.deleteCredentials()
    }

    // MARK: - Save & Load

    @Test func saveAndLoadCredentials() throws {
        let adapter = makeAdapter()
        defer { cleanup(adapter) }

        let credentials = Credentials(token: "ghp_abc123", login: "octocat")
        try adapter.saveCredentials(credentials)

        let loaded = try adapter.loadCredentials()
        #expect(loaded?.token == "ghp_abc123")
        #expect(loaded?.login == "octocat")
    }

    @Test func loadReturnsNilWhenEmpty() throws {
        let adapter = makeAdapter()
        defer { cleanup(adapter) }

        let loaded = try adapter.loadCredentials()
        #expect(loaded == nil)
    }

    @Test func saveOverwritesPreviousCredentials() throws {
        let adapter = makeAdapter()
        defer { cleanup(adapter) }

        try adapter.saveCredentials(Credentials(token: "old-token", login: "old-user"))
        try adapter.saveCredentials(Credentials(token: "new-token", login: "new-user"))

        let loaded = try adapter.loadCredentials()
        #expect(loaded?.token == "new-token")
        #expect(loaded?.login == "new-user")
    }

    // MARK: - Delete

    @Test func deleteRemovesCredentials() throws {
        let adapter = makeAdapter()
        defer { cleanup(adapter) }

        try adapter.saveCredentials(Credentials(token: "ghp_abc123", login: "octocat"))
        try adapter.deleteCredentials()

        let loaded = try adapter.loadCredentials()
        #expect(loaded == nil)
    }

    @Test func deleteWhenEmptyDoesNotThrow() throws {
        let adapter = makeAdapter()
        try adapter.deleteCredentials()
    }

    // MARK: - Legacy migration

    @Test func loadReturnsNilForLegacyTokenOnlyEntry() throws {
        let adapter = makeAdapter()
        defer { cleanup(adapter) }

        // Simulate a legacy keychain entry: plain UTF-8 token, not JSON
        let data = Data("ghp_legacy_token".utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testService,
            kSecAttrAccount as String: testAccount,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        #expect(status == errSecSuccess)

        let loaded = try adapter.loadCredentials()
        #expect(loaded == nil)
    }
}
