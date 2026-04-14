import Foundation

struct NoteToolHandler: Sendable {

    private let adapter: NoteBlobAdapter

    init(adapter: NoteBlobAdapter) {
        self.adapter = adapter
    }

    func listRepositories(_ input: ListRepositoriesInput) throws -> [RepositoryOutput] {
        try adapter.listRepositories().map { repo in
            RepositoryOutput(id: repo.id, name: repo.name, path: repo.path)
        }
    }

    func searchNotes(_ input: SearchNotesInput) async throws -> [SearchResultOutput] {
        let results = try await adapter.searchNotes(
            repositoryID: input.repositoryID,
            query: input.query
        )
        return results.map { result in
            SearchResultOutput(
                name: result.name,
                path: result.path,
                type: result.isFolder ? "folder" : "file",
                snippet: result.snippet
            )
        }
    }
}
