import Foundation

protocol SearchRepositoryAdapter: Sendable {
    func searchRepositories(query: String, credentials: Credentials) async throws -> [Repository]
    func listBranches(for repository: Repository, credentials: Credentials) async throws -> [String]
    func createRepository(
        name: String,
        description: String?,
        isPrivate: Bool,
        credentials: Credentials
    ) async throws -> (repository: Repository, defaultBranch: String)
}
