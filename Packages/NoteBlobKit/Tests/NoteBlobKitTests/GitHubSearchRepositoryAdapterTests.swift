import Foundation
import Testing

@testable import NoteBlobKit

@Suite(.serialized)
struct GitHubSearchRepositoryAdapterTests {

    private let credentials = Credentials(token: "ghp_test", login: "octocat")

    private func makeAdapter() -> GitHubSearchRepositoryAdapter {
        GitHubSearchRepositoryAdapter(session: MockURLProtocol.makeSession())
    }

    // MARK: - URL Parsing

    @Test func parsesHTTPSGitHubURL() async throws {
        MockURLProtocol.handlers = ["/repos/apple/swift": (200, Data("{}".utf8))]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://github.com/apple/swift", credentials: credentials
        )
        #expect(results.count == 1)
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
    }

    @Test func parsesURLWithGitSuffix() async throws {
        MockURLProtocol.handlers = ["/repos/apple/swift": (200, Data("{}".utf8))]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://github.com/apple/swift.git", credentials: credentials
        )
        #expect(results.count == 1)
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
    }

    @Test func parsesWWWGitHubURL() async throws {
        MockURLProtocol.handlers = ["/repos/apple/swift": (200, Data("{}".utf8))]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://www.github.com/apple/swift", credentials: credentials
        )
        #expect(results.count == 1)
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
    }

    @Test func parsesURLWithTrailingSlash() async throws {
        MockURLProtocol.handlers = ["/repos/apple/swift": (200, Data("{}".utf8))]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://github.com/apple/swift/", credentials: credentials
        )
        #expect(results.count == 1)
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
    }

    @Test func parsesURLWithExtraPathComponents() async throws {
        MockURLProtocol.handlers = ["/repos/apple/swift": (200, Data("{}".utf8))]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://github.com/apple/swift/tree/main", credentials: credentials
        )
        #expect(results.count == 1)
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
    }

    @Test func parsesURLWithWhitespace() async throws {
        MockURLProtocol.handlers = ["/repos/apple/swift": (200, Data("{}".utf8))]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "  https://github.com/apple/swift  ", credentials: credentials
        )
        #expect(results.count == 1)
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
    }

    @Test func nonGitHubURLFallsBackToSearch() async throws {
        MockURLProtocol.handlers = [
            "/search/repositories": (200, Data("""
            {"items":[]}
            """.utf8))
        ]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://gitlab.com/user/repo", credentials: credentials
        )
        #expect(results.isEmpty)
    }

    @Test func gitHubURLWithOnlyOwnerFallsBackToSearch() async throws {
        MockURLProtocol.handlers = [
            "/search/repositories": (200, Data("""
            {"items":[]}
            """.utf8))
        ]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://github.com/apple", credentials: credentials
        )
        #expect(results.isEmpty)
    }

    @Test func urlSearchReturnsEmptyWhenRepoDoesNotExist() async throws {
        MockURLProtocol.handlers = ["/repos/apple/nonexistent": (404, Data("{}".utf8))]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(
            query: "https://github.com/apple/nonexistent", credentials: credentials
        )
        #expect(results.isEmpty)
    }

    // MARK: - Search API

    @Test func searchReturnsRepositoriesFromAPI() async throws {
        let responseJSON = """
        {"items":[{"name":"swift","owner":{"login":"apple"}},{"name":"swift-nio","owner":{"login":"apple"}}]}
        """
        MockURLProtocol.handlers = [
            "/search/repositories": (200, Data(responseJSON.utf8))
        ]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(query: "swift", credentials: credentials)

        #expect(results.count == 2)
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
        #expect(results[1].name == "swift-nio")
    }

    @Test func searchScopesQueryToUser() async throws {
        MockURLProtocol.handlers = [
            "/search/repositories": (200, Data("""
            {"items":[]}
            """.utf8))
        ]
        defer { MockURLProtocol.handlers = [:] }

        let results = try await makeAdapter().searchRepositories(query: "myrepo", credentials: credentials)
        #expect(results.isEmpty)
    }
}
