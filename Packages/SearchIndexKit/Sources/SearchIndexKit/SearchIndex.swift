import Foundation

public struct SearchQuery: Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct SearchResponse: Sendable {
    public let results: [SearchResult]
}

public struct SearchResult: Sendable {
    public let path: FilePath
    public let snippet: String
    public let rank: Double
}

public final class SearchIndex: Sendable {

    private let _indexer: WriteSearchIndex

    public init(localURL: URL) {
        do {
            let dbURL = localURL.appendingPathComponent("search_index.db")
            self._indexer = try GRDBSearchIndex(databaseURL: dbURL)
        } catch {
            fatalError("Failed to create search index: \(error)")
        }
    }

    public func search(_ query: SearchQuery) async throws -> SearchResponse {
        let results = try await _indexer.search(query: query.text)
        return SearchResponse(results: results)
    }

    func writeIndex() -> WriteSearchIndex {
        _indexer
    }
}

protocol ReadSearchIndex: Sendable {
    func search(query: String) async throws -> [SearchResult]
    func readEntry(path: FilePath) async throws -> String?
}

struct SearchIndexEntry: Sendable {
    let path: FilePath
    let content: String
}

enum SearchIndexChange: Sendable {
    case updated(SearchIndexEntry)
    case deleted(path: FilePath)
}

protocol WriteSearchIndex: ReadSearchIndex {
    func destroy() async throws
    func rebuild(entries: [SearchIndexEntry]) async throws
    func apply(_ changes: [SearchIndexChange]) async throws
}
