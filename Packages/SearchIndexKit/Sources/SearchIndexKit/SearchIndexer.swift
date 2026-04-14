import Foundation

public enum SearchIndexError: Error {
    case syncFailed(underlying: Error)
    case syncAlreadyInProgress
}

public final class SearchIndexer: Sendable {

    private let source: SnapshotSource
    private let executor: SyncExecutor
    private let stateActor: SyncStateActor

    public init(
        searchIndex: SearchIndex,
        strategy: Strategy
    ) {
        let store = searchIndex.writeIndex()
        self.source = strategy.makeSnapshotSource()
        self.executor = SyncExecutor(source: source, store: store, batchSize: strategy.batchSize)
        self.stateActor = SyncStateActor()
    }

    init(
        indexer: WriteSearchIndex,
        strategy: Strategy
    ) {
        self.source = strategy.makeSnapshotSource()
        self.executor = SyncExecutor(source: source, store: indexer, batchSize: strategy.batchSize)
        self.stateActor = SyncStateActor()
    }

    public func activity() async -> SyncActivity {
        mapActivity(from: await stateActor.phase())
    }

    public func activityStream() async -> AsyncStream<SyncActivity> {
        let phaseStream = await stateActor.phaseStream()
        let (stream, continuation) = AsyncStream.makeStream(of: SyncActivity.self)
        let task = Task {
            for await phase in phaseStream {
                continuation.yield(mapActivity(from: phase))
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    public func indexStatus() async throws -> IndexStatus {
        try await trigger(.startHydration)
        switch await stateActor.phase() {
        case .idle(.checkpoint(.synced(let snapshot))):
            let current = try await source.currentSnapshot()
            return snapshot == current ? .upToDate : .updateAvailable
        case .idle(.checkpoint(.initializing)):
            return .updateAvailable
        case .idle(.empty):
            return .updateAvailable
        case .notHydrated, .hydrating, .syncing, .failed:
            return .updateAvailable
        }
    }

    public func sync() async throws {
        try await trigger(.startSync)
    }

    // MARK: - Private

    private func trigger(_ event: SyncStateActor.Event) async throws {
        let action = try await stateActor.trigger(event)
        switch action {
        case .noop:
            return
        case .hydrate:
            let indexState: IndexState
            do {
                indexState = try await executor.readIndexState()
            } catch {
                try await trigger(.hydrationFailed)
                return
            }
            try await trigger(.hydrationCompleted(indexState))
        case .fullBuild:
            try await performSync { try await self.executor.fullBuild() }
        case .resumeBuild(let snapshot, let alreadyIndexed):
            try await performSync {
                try await self.executor.fullBuild(at: snapshot, startIndex: alreadyIndexed)
            }
        case .incrementalSync(let snapshot):
            try await performSync { try await self.executor.incrementalSync(from: snapshot) }
        }
    }

    private func performSync(_ work: @Sendable () async throws -> SyncCheckpoint) async throws {
        do {
            let checkpoint = try await work()
            try await trigger(.syncCompleted(checkpoint))
        } catch {
            try? await trigger(.syncFailed(error))
            throw error
        }
    }
}

extension SearchIndexer {

    public struct GitStrategyOptions: Sendable {
        public let defaultBranch: String
        public let localURL: URL
        public let gitProtocol: GitProtocol
        public let batchSize: Int

        public init(
            defaultBranch: String, localURL: URL, gitProtocol: GitProtocol, batchSize: Int = 50
        ) {
            self.defaultBranch = defaultBranch
            self.localURL = localURL
            self.gitProtocol = gitProtocol
            self.batchSize = batchSize
        }
    }

    public enum Strategy: Sendable {
        case git(GitStrategyOptions)

        var batchSize: Int {
            switch self {
            case .git(let options): return options.batchSize
            }
        }
    }
}

extension SearchIndexer {

    public enum IndexStatus: Sendable, Equatable {
        case upToDate
        case updateAvailable
    }
}

extension SearchIndexer {

    public enum SyncActivity: Sendable {
        case idle
        case updating(UpdatingState)
        case failed(FailedState)

        public enum SyncPhase: Sendable {
            case initial
            case incremental
        }

        public struct UpdatingState: Sendable {
            public let phase: SyncPhase
        }

        public struct FailedState: Sendable {
            public let phase: SyncPhase
            public let error: SearchIndexError
        }
    }
}

private func mapActivity(from phase: SyncStateActor.Phase) -> SearchIndexer.SyncActivity {
    let syncPhase = { (indexState: IndexState) -> SearchIndexer.SyncActivity.SyncPhase in
        switch indexState {
        case .empty, .checkpoint(.initializing): return .initial
        case .checkpoint(.synced): return .incremental
        }
    }
    switch phase {
    case .notHydrated, .hydrating, .idle:
        return .idle
    case .syncing(let indexState):
        return .updating(.init(phase: syncPhase(indexState)))
    case .failed(let indexState, let error):
        return .failed(
            .init(
                phase: syncPhase(indexState),
                error: .syncFailed(underlying: error)
            ))
    }
}
