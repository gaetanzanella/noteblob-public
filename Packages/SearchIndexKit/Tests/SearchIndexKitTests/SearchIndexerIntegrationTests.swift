import Foundation
import Testing

@testable import SearchIndexKit

struct SearchIndexerIntegrationTests {

    private let defaultBranch = "main"

    /// Creates a temp git repo, a real SearchIndex, and a syncer wired to the CLI git adapter.
    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchIndexIntegration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // git init + initial commit
        try shell("git init", at: root)
        try shell("git checkout -b main", at: root)
        try shell("git config user.email test@test.com", at: root)
        try shell("git config user.name Test", at: root)

        let index = SearchIndex(localURL: root.appendingPathComponent(".search_index"))
        let git = CLIGitProtocol(localURL: root)
        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: defaultBranch,
            localURL: root,
            gitProtocol: git
        )
        let syncer = SearchIndexer(searchIndex: index, strategy: .git(options))

        return Fixture(root: root, index: index, syncer: syncer)
    }

    // MARK: - Initial sync

    @Test func initialSyncIndexesAllFiles() async throws {
        let fixture = try makeFixture()
        try fixture.writeAndCommit("hello.md", content: "hello world")
        try fixture.writeAndCommit("notes/deep.md", content: "deep note content")

        try await fixture.syncer.sync()

        let response = try await fixture.index.search(SearchQuery(text: "hello"))
        #expect(response.results.count == 1)
        #expect(response.results.first?.path == "hello.md")

        let deepResponse = try await fixture.index.search(SearchQuery(text: "deep"))
        #expect(deepResponse.results.count == 1)
    }

    // MARK: - Incremental sync

    @Test func incrementalSyncPicksUpNewCommit() async throws {
        let fixture = try makeFixture()
        try fixture.writeAndCommit("a.md", content: "first note")

        try await fixture.syncer.sync()

        try fixture.writeAndCommit("b.md", content: "second note")

        try await fixture.syncer.sync()

        let response = try await fixture.index.search(SearchQuery(text: "second"))
        #expect(response.results.count == 1)
        #expect(response.results.first?.path == "b.md")
    }

    @Test func incrementalSyncPicksUpModifiedFile() async throws {
        let fixture = try makeFixture()
        try fixture.writeAndCommit("a.md", content: "original content")

        try await fixture.syncer.sync()

        try fixture.writeAndCommit("a.md", content: "updated content")

        try await fixture.syncer.sync()

        let originalResponse = try await fixture.index.search(SearchQuery(text: "original"))
        #expect(originalResponse.results.isEmpty)

        let updatedResponse = try await fixture.index.search(SearchQuery(text: "updated"))
        #expect(updatedResponse.results.count == 1)
    }

    @Test func incrementalSyncPicksUpDeletedFile() async throws {
        let fixture = try makeFixture()
        try fixture.writeAndCommit("a.md", content: "to be deleted")
        try fixture.writeAndCommit("b.md", content: "to be kept")

        try await fixture.syncer.sync()

        try fixture.deleteAndCommit("a.md")

        try await fixture.syncer.sync()

        let response = try await fixture.index.search(SearchQuery(text: "deleted"))
        #expect(response.results.isEmpty)

        let keptResponse = try await fixture.index.search(SearchQuery(text: "kept"))
        #expect(keptResponse.results.count == 1)
    }

    // MARK: - No-op sync

    @Test func syncWithNoNewCommitsIsNoOp() async throws {
        let fixture = try makeFixture()
        try fixture.writeAndCommit("a.md", content: "hello")

        try await fixture.syncer.sync()
        try await fixture.syncer.sync()

        let response = try await fixture.index.search(SearchQuery(text: "hello"))
        #expect(response.results.count == 1)
    }

    // MARK: - Multiple commits between syncs

    @Test func syncCatchesUpMultipleCommits() async throws {
        let fixture = try makeFixture()
        try fixture.writeAndCommit("a.md", content: "first")

        try await fixture.syncer.sync()

        try fixture.writeAndCommit("b.md", content: "second")
        try fixture.writeAndCommit("c.md", content: "third")
        try fixture.deleteAndCommit("a.md")

        try await fixture.syncer.sync()

        let firstResponse = try await fixture.index.search(SearchQuery(text: "first"))
        #expect(firstResponse.results.isEmpty)

        let secondResponse = try await fixture.index.search(SearchQuery(text: "second"))
        #expect(secondResponse.results.count == 1)

        let thirdResponse = try await fixture.index.search(SearchQuery(text: "third"))
        #expect(thirdResponse.results.count == 1)
    }

    // MARK: - Index status

    @Test func indexStatusReflectsGitState() async throws {
        let fixture = try makeFixture()
        try fixture.writeAndCommit("a.md", content: "hello")

        try await fixture.syncer.sync()

        let upToDate = try await fixture.syncer.indexStatus()
        #expect(upToDate == .upToDate)

        try fixture.writeAndCommit("b.md", content: "world")

        let updateAvailable = try await fixture.syncer.indexStatus()
        #expect(updateAvailable == .updateAvailable)
    }
}

// MARK: - Fixture

private struct Fixture {
    let root: URL
    let index: SearchIndex
    let syncer: SearchIndexer

    func writeAndCommit(_ relativePath: String, content: String) throws {
        let fileURL = root.appendingPathComponent(relativePath)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        try shell("git add \(relativePath)", at: root)
        try shell("git commit -m \"add \(relativePath)\"", at: root)
    }

    func deleteAndCommit(_ relativePath: String) throws {
        let fileURL = root.appendingPathComponent(relativePath)
        try FileManager.default.removeItem(at: fileURL)
        try shell("git add \(relativePath)", at: root)
        try shell("git commit -m \"delete \(relativePath)\"", at: root)
    }
}
