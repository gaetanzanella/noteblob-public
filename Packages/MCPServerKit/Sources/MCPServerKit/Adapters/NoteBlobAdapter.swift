import Foundation

public struct MCPRepository: Sendable {
    public let id: String
    public let name: String
    public let path: String

    public init(id: String, name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}

public struct MCPSearchResult: Sendable {
    public let name: String
    public let path: String
    public let isFolder: Bool
    public let snippet: String?

    public init(name: String, path: String, isFolder: Bool, snippet: String?) {
        self.name = name
        self.path = path
        self.isFolder = isFolder
        self.snippet = snippet
    }
}

public protocol NoteBlobAdapter: Sendable {
    func listRepositories() throws -> [MCPRepository]
    func searchNotes(repositoryID: String, query: String) async throws -> [MCPSearchResult]
}
