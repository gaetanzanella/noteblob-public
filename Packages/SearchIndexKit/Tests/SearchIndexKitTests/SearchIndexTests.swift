import Foundation
import Testing
@testable import SearchIndexKit

struct SearchIndexTests {

    private func makeIndex() throws -> SearchIndex {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return SearchIndex(localURL: url)
    }

    // MARK: - Empty index

    @Test func searchOnEmptyIndexReturnsEmpty() async throws {
        let index = try makeIndex()
        let response = try await index.search(SearchQuery(text: "hello"))
        #expect(response.results.isEmpty)
    }

    // MARK: - Rebuild

    @Test func searchAfterRebuildFindsMatch() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "notes/hello.md", content: "hello world"),
            SearchIndexEntry(path: "notes/goodbye.md", content: "goodbye world"),
        ])
        let response = try await index.search(SearchQuery(text: "hello"))
        #expect(response.results.count == 1)
        #expect(response.results.first?.path == "notes/hello.md")
    }

    @Test func searchMatchesMultipleResults() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "swift programming"),
            SearchIndexEntry(path: "b.md", content: "swift language"),
            SearchIndexEntry(path: "c.md", content: "rust programming"),
        ])
        let response = try await index.search(SearchQuery(text: "swift"))
        #expect(response.results.count == 2)
    }

    @Test func rebuildReplacesExistingIndex() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "alpha"),
        ])
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "b.md", content: "beta"),
        ])
        let alphaResponse = try await index.search(SearchQuery(text: "alpha"))
        #expect(alphaResponse.results.isEmpty)
        let betaResponse = try await index.search(SearchQuery(text: "beta"))
        #expect(betaResponse.results.count == 1)
    }

    // MARK: - Apply changes

    @Test func applyAddedEntry() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "hello"),
        ])
        try await indexer.apply([
            .updated(SearchIndexEntry(path: "b.md", content: "hello again")),
        ])
        let response = try await index.search(SearchQuery(text: "hello"))
        #expect(response.results.count == 2)
    }

    @Test func applyUpdatedEntry() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "hello"),
        ])
        try await indexer.apply([
            .updated(SearchIndexEntry(path: "a.md", content: "goodbye")),
        ])
        let helloResponse = try await index.search(SearchQuery(text: "hello"))
        #expect(helloResponse.results.isEmpty)
        let goodbyeResponse = try await index.search(SearchQuery(text: "goodbye"))
        #expect(goodbyeResponse.results.count == 1)
    }

    @Test func applyDeletedEntry() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "hello"),
            SearchIndexEntry(path: "b.md", content: "hello world"),
        ])
        try await indexer.apply([
            .deleted(path: "a.md"),
        ])
        let response = try await index.search(SearchQuery(text: "hello"))
        #expect(response.results.count == 1)
        #expect(response.results.first?.path == "b.md")
    }

    // MARK: - Destroy

    @Test func destroyClearsIndex() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "hello"),
        ])
        try await indexer.destroy()
        let response = try await index.search(SearchQuery(text: "hello"))
        #expect(response.results.isEmpty)
    }

    // MARK: - Snippets

    @Test func searchResultContainsSnippet() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "The quick brown fox jumps over the lazy dog"),
        ])
        let response = try await index.search(SearchQuery(text: "fox"))
        #expect(response.results.count == 1)
        #expect(response.results.first?.snippet.contains("fox") == true)
    }

    // MARK: - Ranking

    @Test func resultsAreRankedByRelevance() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "a.md", content: "swift"),
            SearchIndexEntry(path: "b.md", content: "swift swift swift"),
        ])
        let response = try await index.search(SearchQuery(text: "swift"))
        #expect(response.results.count == 2)
        #expect(response.results.first?.path == "b.md")
    }

    // MARK: - Sync state as entry

    @Test func syncStatePersistedAsEntry() async throws {
        let index = try makeIndex()
        let indexer = index.writeIndex()
        try await indexer.rebuild(entries: [
            SearchIndexEntry(path: "__sync_state__", content: "abc123"),
        ])
        let response = try await index.search(SearchQuery(text: "abc123"))
        // Sync state should not appear in search results
        #expect(response.results.isEmpty)
    }
}
