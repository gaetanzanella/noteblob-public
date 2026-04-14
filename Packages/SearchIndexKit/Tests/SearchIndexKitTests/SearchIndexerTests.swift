import Foundation
import Testing

@testable import SearchIndexKit

struct SearchIndexerTests {

    private let defaultBranch = "main"

    private func makeSyncer(
        indexer: MockWriteSearchIndex = MockWriteSearchIndex(),
        git: MockGitProtocol = MockGitProtocol()
    ) -> (SearchIndexer, MockWriteSearchIndex, MockGitProtocol) {
        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: defaultBranch,
            localURL: FileManager.default.temporaryDirectory,
            gitProtocol: git
        )
        let syncer = SearchIndexer(indexer: indexer, strategy: .git(options))
        return (syncer, indexer, git)
    }

    // MARK: - Initial sync

    @Test func initialSyncDoesFullRebuild() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md", "b.md"]
        git.fileContents["main"] = ["a.md": "hello", "b.md": "world"]

        try await syncer.sync()

        // Initial sync uses batched apply, not rebuild
        #expect(indexer.applyCallCount >= 1)
        #expect(indexer.entries.filter { $0.path != "__sync_state__" }.count == 2)
    }

    @Test func initialSyncStoresCommitHash() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()

        // The sync state should be stored as an entry
        let syncStateEntry = indexer.entries.first { $0.path == "__sync_state__" }
        #expect(syncStateEntry?.content == "abc123")
    }

    // MARK: - No-op sync

    @Test func syncWithSameHashIsNoOp() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()
        let applyCountAfterFirstSync = indexer.applyCallCount

        try await syncer.sync()
        #expect(indexer.applyCallCount == applyCountAfterFirstSync)
    }

    // MARK: - Incremental sync

    @Test func syncWithNewHashDoesIncrementalUpdate() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()
        let applyCountAfterInit = indexer.applyCallCount

        git.commitHashes["main"] = "def456"
        git.diffChanges = [.added("b.md")]
        git.fileContents["main"]?["b.md"] = "world"

        try await syncer.sync()

        #expect(indexer.applyCallCount == applyCountAfterInit + 1)
        let contentChanges = indexer.changes.last?.filter {
            if case .updated(let e) = $0 { return e.path != "__sync_state__" }
            if case .deleted = $0 { return true }
            return false
        }
        #expect(contentChanges?.count == 1)
    }

    @Test func incrementalSyncHandlesModifiedFiles() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()
        let applyCountAfterInit = indexer.applyCallCount

        git.commitHashes["main"] = "def456"
        git.diffChanges = [.modified("a.md")]
        git.fileContents["main"]?["a.md"] = "updated"

        try await syncer.sync()

        #expect(indexer.applyCallCount == applyCountAfterInit + 1)
        let lastEntry = indexer.entries.first { $0.path == "a.md" }
        #expect(lastEntry?.content == "updated")
    }

    @Test func incrementalSyncHandlesDeletedFiles() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md", "b.md"]
        git.fileContents["main"] = ["a.md": "hello", "b.md": "world"]

        try await syncer.sync()
        let applyCountAfterInit = indexer.applyCallCount

        git.commitHashes["main"] = "def456"
        git.diffChanges = [.deleted("b.md")]

        try await syncer.sync()

        #expect(indexer.applyCallCount == applyCountAfterInit + 1)
        #expect(indexer.entries.filter { $0.path != "__sync_state__" }.count == 1)
    }

    @Test func incrementalSyncUpdatesStoredHash() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()

        git.commitHashes["main"] = "def456"
        git.diffChanges = []

        try await syncer.sync()

        let syncStateEntry = indexer.entries.first { $0.path == "__sync_state__" }
        #expect(syncStateEntry?.content == "def456")
    }

    // MARK: - Index status

    @Test func indexStatusUpToDateWhenHashMatches() async throws {
        let (syncer, _, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()

        let status = try await syncer.indexStatus()
        #expect(status == .upToDate)
    }

    @Test func indexStatusUpdateAvailableWhenHashDiffers() async throws {
        let (syncer, _, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()
        git.commitHashes["main"] = "def456"

        let status = try await syncer.indexStatus()
        #expect(status == .updateAvailable)
    }

    // MARK: - Error handling

    @Test func syncAfterFailureDoesFullRebuild() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.shouldThrow = MockGitError.refNotFound
        try? await syncer.sync()

        git.shouldThrow = nil
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()

        #expect(indexer.applyCallCount >= 1)
        #expect(indexer.entries.filter { $0.path != "__sync_state__" }.count == 1)
    }

    // MARK: - Interrupted initial sync (resumable)

    @Test func initialSyncProcessesInBatches() async throws {
        let (syncer, indexer, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md", "b.md", "c.md", "d.md", "e.md"]
        git.fileContents["main"] = [
            "a.md": "aaa", "b.md": "bbb", "c.md": "ccc",
            "d.md": "ddd", "e.md": "eee",
        ]

        try await syncer.sync()

        // Should have called apply multiple times (batched), not one big rebuild
        #expect(indexer.applyCallCount >= 1)
        // All files should be indexed
        let contentEntries = indexer.entries.filter { $0.path != SyncToken.key }
        #expect(contentEntries.count == 5)
    }

    @Test func interruptedInitialSyncResumesFromLastBatch() async throws {
        let indexer = MockWriteSearchIndex()
        let git = MockGitProtocol()

        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md", "b.md", "c.md", "d.md", "e.md"]
        git.fileContents["main"] = [
            "a.md": "aaa", "b.md": "bbb", "c.md": "ccc",
            "d.md": "ddd", "e.md": "eee",
        ]

        // Simulate a previous interrupted init: 2 files were indexed
        indexer.entries = [
            SearchIndexEntry(path: "a.md", content: "aaa"),
            SearchIndexEntry(path: "b.md", content: "bbb"),
            // Token indicates init in progress, 2 of 5 done for commit abc123
            SearchIndexEntry(path: SyncToken.key, content: "init:abc123:2"),
        ]

        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: "main",
            localURL: FileManager.default.temporaryDirectory,
            gitProtocol: git
        )
        let syncer = SearchIndexer(indexer: indexer, strategy: .git(options))

        try await syncer.sync()

        // Should NOT have called rebuild (would lose existing entries)
        #expect(indexer.rebuildCallCount == 0)
        // Should have applied the remaining files
        let contentEntries = indexer.entries.filter { $0.path != SyncToken.key }
        #expect(contentEntries.count == 5)
        // Token should now be the final commit hash, not "init:..."
        let token = indexer.entries.first { $0.path == SyncToken.key }
        #expect(token?.content == "abc123")
    }

    @Test func interruptedInitSyncWithNewCommitRestartsFromScratch() async throws {
        let indexer = MockWriteSearchIndex()
        let git = MockGitProtocol()

        // The commit has changed since the interrupted init
        git.commitHashes["main"] = "def456"
        git.files["main"] = ["a.md", "b.md"]
        git.fileContents["main"] = ["a.md": "aaa", "b.md": "bbb"]

        // Simulate interrupted init for a DIFFERENT commit
        indexer.entries = [
            SearchIndexEntry(path: "a.md", content: "old"),
            SearchIndexEntry(path: SyncToken.key, content: "init:abc123:1"),
        ]

        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: "main",
            localURL: FileManager.default.temporaryDirectory,
            gitProtocol: git
        )
        let syncer = SearchIndexer(indexer: indexer, strategy: .git(options))

        try await syncer.sync()

        // Should have done a full rebuild since commit changed
        let contentEntries = indexer.entries.filter { $0.path != SyncToken.key }
        #expect(contentEntries.count == 2)
        let token = indexer.entries.first { $0.path == SyncToken.key }
        #expect(token?.content == "def456")
    }

    @Test func interruptedInitSyncIsResilientToFileOrderChange() async throws {
        let indexer = MockWriteSearchIndex()
        let git = MockGitProtocol()

        git.commitHashes["main"] = "abc123"
        // On resume, allFiles returns a DIFFERENT order than the original sync
        // Original order was: a.md, b.md, c.md, d.md, e.md
        // First 2 (a.md, b.md) were indexed before interruption
        // Now the source returns them shuffled
        git.files["main"] = ["d.md", "b.md", "e.md", "a.md", "c.md"]
        git.fileContents["main"] = [
            "a.md": "aaa", "b.md": "bbb", "c.md": "ccc",
            "d.md": "ddd", "e.md": "eee",
        ]

        indexer.entries = [
            SearchIndexEntry(path: "a.md", content: "aaa"),
            SearchIndexEntry(path: "b.md", content: "bbb"),
            SearchIndexEntry(path: SyncToken.key, content: "init:abc123:2"),
        ]

        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: "main",
            localURL: FileManager.default.temporaryDirectory,
            gitProtocol: git
        )
        let syncer = SearchIndexer(indexer: indexer, strategy: .git(options))

        try await syncer.sync()

        let contentEntries = indexer.entries.filter { $0.path != SyncToken.key }
        // All 5 files should be indexed with correct content
        #expect(contentEntries.count == 5)
        for entry in contentEntries {
            let expected = String(entry.path.first!) + String(entry.path.first!) + String(entry.path.first!)
            #expect(entry.content == expected)
        }
        let token = indexer.entries.first { $0.path == SyncToken.key }
        #expect(token?.content == "abc123")
    }

    // MARK: - Crash simulation

    @Test func crashDuringInitBatchResumesFromLastCompletedBatch() async throws {
        let indexer = MockWriteSearchIndex()
        let git = MockGitProtocol()

        git.commitHashes["main"] = "abc123"
        // 4 files, batchSize=2 → 2 batches
        git.files["main"] = ["a.md", "b.md", "c.md", "d.md"]
        git.fileContents["main"] = [
            "a.md": "aaa", "b.md": "bbb", "c.md": "ccc", "d.md": "ddd",
        ]

        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: "main",
            localURL: FileManager.default.temporaryDirectory,
            gitProtocol: git,
            batchSize: 2
        )

        // First sync: crash after first batch (apply #1 succeeds, apply #2 fails)
        indexer.throwOnApplyAfter = 1
        let syncer1 = SearchIndexer(indexer: indexer, strategy: .git(options))
        try? await syncer1.sync()

        // First batch should have been persisted with init token
        let contentAfterCrash = indexer.entries.filter { $0.path != SyncToken.key }
        #expect(contentAfterCrash.count == 2)
        let tokenAfterCrash = indexer.entries.first { $0.path == SyncToken.key }
        #expect(tokenAfterCrash?.content == "init:abc123:2")

        // Second sync: no crash, new indexer instance (simulates app restart)
        indexer.throwOnApplyAfter = nil
        indexer.applyCallCount = 0
        let syncer2 = SearchIndexer(indexer: indexer, strategy: .git(options))
        try await syncer2.sync()

        // All 4 files should now be indexed
        let contentAfterResume = indexer.entries.filter { $0.path != SyncToken.key }
        #expect(contentAfterResume.count == 4)
        let tokenAfterResume = indexer.entries.first { $0.path == SyncToken.key }
        #expect(tokenAfterResume?.content == "abc123")
    }

    @Test func crashDuringFinalInitBatchResumesCorrectly() async throws {
        let indexer = MockWriteSearchIndex()
        let git = MockGitProtocol()

        git.commitHashes["main"] = "abc123"
        // 4 files, batchSize=2 → 2 batches. Crash on the final batch.
        git.files["main"] = ["a.md", "b.md", "c.md", "d.md"]
        git.fileContents["main"] = [
            "a.md": "aaa", "b.md": "bbb", "c.md": "ccc", "d.md": "ddd",
        ]

        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: "main",
            localURL: FileManager.default.temporaryDirectory,
            gitProtocol: git,
            batchSize: 2
        )

        // Crash on second apply (the final batch)
        indexer.throwOnApplyAfter = 1
        let syncer1 = SearchIndexer(indexer: indexer, strategy: .git(options))
        try? await syncer1.sync()

        // Only first batch persisted, token is init:abc123:2
        let tokenAfterCrash = indexer.entries.first { $0.path == SyncToken.key }
        #expect(tokenAfterCrash?.content == "init:abc123:2")

        // Resume: should pick up remaining files
        indexer.throwOnApplyAfter = nil
        indexer.applyCallCount = 0
        let syncer2 = SearchIndexer(indexer: indexer, strategy: .git(options))
        try await syncer2.sync()

        let contentAfterResume = indexer.entries.filter { $0.path != SyncToken.key }
        #expect(contentAfterResume.count == 4)
        let tokenAfterResume = indexer.entries.first { $0.path == SyncToken.key }
        #expect(tokenAfterResume?.content == "abc123")
    }

    @Test func crashDuringIncrementalSyncRetriesIncremental() async throws {
        let indexer = MockWriteSearchIndex()
        let git = MockGitProtocol()

        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "aaa"]

        let options = SearchIndexer.GitStrategyOptions(
            defaultBranch: "main",
            localURL: FileManager.default.temporaryDirectory,
            gitProtocol: git
        )

        // Initial sync succeeds
        let syncer1 = SearchIndexer(indexer: indexer, strategy: .git(options))
        try await syncer1.sync()

        let tokenAfterInit = indexer.entries.first { $0.path == SyncToken.key }
        #expect(tokenAfterInit?.content == "abc123")

        // New commit, but incremental apply will crash
        git.commitHashes["main"] = "def456"
        git.diffChanges = [.added("b.md")]
        git.fileContents["main"]?["b.md"] = "bbb"

        indexer.throwOnApplyAfter = indexer.applyCallCount
        let syncer2 = SearchIndexer(indexer: indexer, strategy: .git(options))
        try? await syncer2.sync()

        // Token should still be the old hash (incremental failed, nothing persisted)
        let tokenAfterCrash = indexer.entries.first { $0.path == SyncToken.key }
        #expect(tokenAfterCrash?.content == "abc123")

        // Retry: should succeed
        indexer.throwOnApplyAfter = nil
        indexer.applyCallCount = 0
        let syncer3 = SearchIndexer(indexer: indexer, strategy: .git(options))
        try await syncer3.sync()

        let contentAfterRetry = indexer.entries.filter { $0.path != SyncToken.key }
        #expect(contentAfterRetry.count == 2)
        let tokenAfterRetry = indexer.entries.first { $0.path == SyncToken.key }
        #expect(tokenAfterRetry?.content == "def456")
    }
}
