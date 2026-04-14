import Foundation
import NoteBlobKit
import MCPServerKit

private struct RepositoryNotFoundError: LocalizedError {
    let id: String
    var errorDescription: String? { "Repository not found: \(id)" }
}

struct NoteBlobRepositoryAdapter: NoteBlobAdapter {

    private let dependencyProvider: DependencyProvider

    init(dependencyProvider: DependencyProvider) {
        self.dependencyProvider = dependencyProvider
    }

    func listRepositories() throws -> [MCPRepository] {
        let folders = try dependencyProvider.makeFolderSyncService().syncedFolders()
        let pathProvider = dependencyProvider.makeLocalPathProvider()
        return folders.map { folder in
            MCPRepository(
                id: folder.id,
                name: folder.name,
                path: pathProvider.localPath(for: folder).path
            )
        }
    }

    func searchNotes(repositoryID: String, query: String) async throws -> [MCPSearchResult] {
        let folders = try dependencyProvider.makeFolderSyncService().syncedFolders()
        guard let folder = folders.first(where: { $0.id == repositoryID }) else {
            throw RepositoryNotFoundError(id: repositoryID)
        }
        let service = dependencyProvider.makeNoteService(for: folder)
        let results = try await service.searchItems(in: folder, query: query)
        return results.map { result in
            MCPSearchResult(
                name: result.item.name,
                path: result.item.path.value,
                isFolder: result.item.isFolder,
                snippet: result.snippet?.text
            )
        }
    }
}
