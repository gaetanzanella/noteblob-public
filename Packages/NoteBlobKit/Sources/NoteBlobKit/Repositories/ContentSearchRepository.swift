import Foundation

public struct ContentSearchSnippet: Sendable {
    public let text: String
    public let matchRange: Range<String.Index>
}

struct ContentSearchResult: Sendable {
    let path: String
    let snippet: ContentSearchSnippet
}

protocol ContentSearchRepository: Sendable {
    func search(query: String) async throws -> [ContentSearchResult]
}
