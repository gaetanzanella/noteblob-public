import Foundation
@testable import MCPServerKit

struct MockNoteBlobAdapter: NoteBlobAdapter {
    let repositories: [MCPRepository]
    let searchResults: [MCPSearchResult]

    func listRepositories() throws -> [MCPRepository] { repositories }

    func searchNotes(repositoryID: String, query: String) async throws -> [MCPSearchResult] {
        guard repositories.contains(where: { $0.id == repositoryID }) else {
            throw MCPToolError.folderNotFound(repositoryID)
        }
        return searchResults.filter { result in
            result.name.localizedCaseInsensitiveContains(query)
                || (result.snippet?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}
