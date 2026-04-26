import Foundation

final class GitHubSearchRepositoryAdapter: SearchRepositoryAdapter, @unchecked Sendable {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchRepositories(query: String, credentials: Credentials) async throws -> [Repository] {
        if let repository = Self.parseGitHubURL(query) {
            let exists = await repositoryExists(repository, credentials: credentials)
            return exists ? [repository] : []
        }

        let scopedQuery = "user:\(credentials.login) \(query)"
        let encoded = scopedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopedQuery
        let url = URL(string: "https://api.github.com/search/repositories?q=\(encoded)&per_page=30")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let result = try JSONDecoder().decode(GitHubSearchResult.self, from: data)

        return result.items.map { item in
            Repository(owner: item.owner.login, name: item.name)
        }
    }

    func createRepository(
        name: String,
        description: String?,
        isPrivate: Bool,
        credentials: Credentials
    ) async throws -> (repository: Repository, defaultBranch: String) {
        let url = URL(string: "https://api.github.com/user/repos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateRepositoryRequest(
            name: name,
            description: description,
            isPrivate: isPrivate,
            autoInit: true
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        guard let http, (200..<300).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data) ?? "GitHub API returned status \(http?.statusCode ?? -1)"
            throw NoteBlobError.syncFailed(message)
        }

        let created = try JSONDecoder().decode(GitHubCreatedRepository.self, from: data)
        return (
            repository: Repository(owner: created.owner.login, name: created.name),
            defaultBranch: created.defaultBranch
        )
    }

    func listBranches(for repository: Repository, credentials: Credentials) async throws -> [String] {
        let url = URL(string: "https://api.github.com/repos/\(repository.owner)/\(repository.name)/branches?per_page=100")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        let branches = try JSONDecoder().decode([GitHubBranch].self, from: data)
        return branches.map(\.name)
    }

    // MARK: - Private

    /// Parses `https://github.com/owner/repo` or `github.com/owner/repo` into a Repository.
    private static func parseGitHubURL(_ query: String) -> Repository? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host,
              host == "github.com" || host == "www.github.com"
        else {
            return nil
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2 else { return nil }
        let name = components[1].hasSuffix(".git") ? String(components[1].dropLast(4)) : components[1]
        return Repository(owner: components[0], name: name)
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data) else {
            return nil
        }
        return decoded.message
    }

    private func repositoryExists(_ repository: Repository, credentials: Credentials) async -> Bool {
        guard let url = URL(string: "https://api.github.com/repos/\(repository.owner)/\(repository.name)") else {
            return false
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (_, response) = try? await session.data(for: request) else {
            return false
        }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}

// MARK: - Decodable

private struct GitHubSearchResult: Decodable {
    let items: [GitHubSearchItem]
}

private struct GitHubBranch: Decodable {
    let name: String
}

private struct GitHubSearchItem: Decodable {
    let name: String
    let owner: Owner

    struct Owner: Decodable {
        let login: String
    }
}

private struct CreateRepositoryRequest: Encodable {
    let name: String
    let description: String?
    let isPrivate: Bool
    let autoInit: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case isPrivate = "private"
        case autoInit = "auto_init"
    }
}

private struct GitHubCreatedRepository: Decodable {
    let name: String
    let owner: Owner
    let defaultBranch: String

    struct Owner: Decodable {
        let login: String
    }

    enum CodingKeys: String, CodingKey {
        case name
        case owner
        case defaultBranch = "default_branch"
    }
}

private struct GitHubErrorResponse: Decodable {
    let message: String
}
