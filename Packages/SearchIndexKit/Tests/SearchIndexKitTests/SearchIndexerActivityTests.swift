import Foundation
import Testing

@testable import SearchIndexKit

private actor ActivityCollector {
    var values: [SearchIndexer.SyncActivity] = []
    private var waiters: [(@Sendable ([SearchIndexer.SyncActivity]) -> Bool, CheckedContinuation<Void, Never>)] = []

    func append(_ activity: SearchIndexer.SyncActivity) {
        values.append(activity)
        for (index, (predicate, continuation)) in waiters.enumerated().reversed() {
            if predicate(values) {
                waiters.remove(at: index)
                continuation.resume()
            }
        }
    }

    func waitUntil(_ predicate: @escaping @Sendable ([SearchIndexer.SyncActivity]) -> Bool) async {
        if predicate(values) { return }
        await withCheckedContinuation { continuation in
            waiters.append((predicate, continuation))
        }
    }
}

struct SearchIndexerActivityTests {

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

    @Test func activityIsIdleBeforeSync() async {
        let (syncer, _, _) = makeSyncer()
        let activity = await syncer.activity()
        guard case .idle = activity else {
            #expect(Bool(false), "Expected .idle, got \(activity)")
            return
        }
    }

    @Test func activityIsIdleAfterSync() async throws {
        let (syncer, _, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()

        let activity = await syncer.activity()
        guard case .idle = activity else {
            #expect(Bool(false), "Expected .idle, got \(activity)")
            return
        }
    }

    @Test func activityStreamEmitsUpdatingDuringSync() async throws {
        let (syncer, _, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        let stream = await syncer.activityStream()
        let collector = ActivityCollector()

        let collectTask = Task {
            for await activity in stream {
                await collector.append(activity)
            }
        }
        await Task.yield()

        try await syncer.sync()
        await collector.waitUntil { activities in
            let hasUpdating = activities.contains { if case .updating = $0 { return true }; return false }
            let hasIdleAfter = activities.last.map { if case .idle = $0 { return true }; return false } ?? false
            return hasUpdating && hasIdleAfter
        }
        collectTask.cancel()

        let collected = await collector.values
        let hasUpdating = collected.contains {
            if case .updating = $0 { return true }
            return false
        }
        #expect(hasUpdating)

        let hasIdle = collected.contains {
            if case .idle = $0 { return true }
            return false
        }
        #expect(hasIdle)
    }

    @Test func activityStreamEmitsInitialPhaseOnFirstSync() async throws {
        let (syncer, _, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        let stream = await syncer.activityStream()
        let collector = ActivityCollector()

        let collectTask = Task {
            for await activity in stream {
                await collector.append(activity)
            }
        }
        await Task.yield()

        try await syncer.sync()
        await collector.waitUntil { activities in
            activities.contains { if case .updating = $0 { return true }; return false }
        }
        collectTask.cancel()

        let collected = await collector.values
        let phases = collected.compactMap { activity -> SearchIndexer.SyncActivity.SyncPhase? in
            if case .updating(let state) = activity { return state.phase }
            return nil
        }
        #expect(phases.contains(.initial))
    }

    @Test func activityStreamEmitsIncrementalPhaseOnSubsequentSync() async throws {
        let (syncer, _, git) = makeSyncer()
        git.commitHashes["main"] = "abc123"
        git.files["main"] = ["a.md"]
        git.fileContents["main"] = ["a.md": "hello"]

        try await syncer.sync()

        git.commitHashes["main"] = "def456"
        git.diffChanges = [.added("b.md")]
        git.fileContents["main"]?["b.md"] = "world"

        let stream = await syncer.activityStream()
        let collector = ActivityCollector()

        let collectTask = Task {
            for await activity in stream {
                await collector.append(activity)
            }
        }
        await Task.yield()

        try await syncer.sync()
        await collector.waitUntil { activities in
            activities.contains { if case .updating = $0 { return true }; return false }
        }
        collectTask.cancel()

        let collected = await collector.values
        let phases = collected.compactMap { activity -> SearchIndexer.SyncActivity.SyncPhase? in
            if case .updating(let state) = activity { return state.phase }
            return nil
        }
        #expect(phases.contains(.incremental))
    }

    @Test func activityStreamEmitsFailedOnError() async throws {
        let (syncer, _, git) = makeSyncer()
        git.shouldThrow = MockGitError.refNotFound

        let stream = await syncer.activityStream()
        let collector = ActivityCollector()

        let collectTask = Task {
            for await activity in stream {
                await collector.append(activity)
            }
        }
        await Task.yield()

        try? await syncer.sync()
        await collector.waitUntil { activities in
            activities.contains { if case .failed = $0 { return true }; return false }
        }
        collectTask.cancel()

        let collected = await collector.values
        let hasFailed = collected.contains {
            if case .failed = $0 { return true }
            return false
        }
        #expect(hasFailed)
    }
}
