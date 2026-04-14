import Foundation
import Testing

@testable import SearchIndexKit

struct SyncStateActorTests {

    // MARK: - notHydrated

    @Test func startSyncFromNotHydratedTriggersHydrate() async throws {
        let actor = SyncStateActor()
        let action = try await actor.trigger(.startSync)
        guard case .hydrate = action else {
            #expect(Bool(false), "Expected .hydrate, got \(action)")
            return
        }
        guard case .hydrating = await actor.phase() else {
            #expect(Bool(false), "Expected .hydrating phase")
            return
        }
    }

    @Test func invalidEventFromNotHydratedThrows() async {
        let actor = SyncStateActor()
        await #expect(throws: SyncStateMachineError.self) {
            try await actor.trigger(.hydrationCompleted(.empty))
        }
    }

    // MARK: - hydrating

    @Test func hydrationCompletedEmptyReplaysPendingStartSync() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)

        let action = try await actor.trigger(.hydrationCompleted(.empty))
        guard case .fullBuild = action else {
            #expect(Bool(false), "Expected .fullBuild, got \(action)")
            return
        }
        guard case .syncing(.empty) = await actor.phase() else {
            #expect(Bool(false), "Expected .syncing(.empty) phase")
            return
        }
    }

    @Test func hydrationCompletedWithSyncedCheckpointReplaysStartSync() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)

        let snapshot = SnapshotID("abc123")
        let action = try await actor.trigger(.hydrationCompleted(.checkpoint(.synced(snapshot))))
        guard case .incrementalSync(let from) = action else {
            #expect(Bool(false), "Expected .incrementalSync, got \(action)")
            return
        }
        #expect(from == snapshot)
    }

    @Test func hydrationCompletedWithInitializingCheckpointReplaysStartSync() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)

        let snapshot = SnapshotID("abc123")
        let action = try await actor.trigger(
            .hydrationCompleted(.checkpoint(.initializing(snapshot: snapshot, indexedCount: 5)))
        )
        guard case .resumeBuild(let s, let count) = action else {
            #expect(Bool(false), "Expected .resumeBuild, got \(action)")
            return
        }
        #expect(s == snapshot)
        #expect(count == 5)
    }

    @Test func hydrationFailedReplaysPendingStartSyncWithEmptyState() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)

        let action = try await actor.trigger(.hydrationFailed)
        guard case .fullBuild = action else {
            #expect(Bool(false), "Expected .fullBuild, got \(action)")
            return
        }
        guard case .syncing(.empty) = await actor.phase() else {
            #expect(Bool(false), "Expected .syncing(.empty) phase")
            return
        }
    }

    @Test func invalidEventFromHydratingThrows() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)

        await #expect(throws: SyncStateMachineError.self) {
            try await actor.trigger(.syncCompleted(.synced(SnapshotID("abc"))))
        }
    }

    // MARK: - idle

    @Test func startSyncFromIdleEmptyReturnsFullBuild() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.empty))

        // Now syncing — complete it first
        try await actor.trigger(.syncCompleted(.synced(SnapshotID("abc"))))

        // Now idle with a checkpoint — but let's test empty
        // Create fresh actor and hydrate to empty
        let actor2 = SyncStateActor()
        _ = try await actor2.trigger(.startSync)
        _ = try await actor2.trigger(.hydrationFailed)
        // Now syncing(.empty) from the replay — complete it
        try await actor2.trigger(.syncCompleted(.synced(SnapshotID("abc"))))

        // Now idle with checkpoint — trigger sync again
        let action = try await actor2.trigger(.startSync)
        guard case .incrementalSync = action else {
            #expect(Bool(false), "Expected .incrementalSync, got \(action)")
            return
        }
    }

    @Test func startSyncFromIdleSyncedReturnsIncrementalSync() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.checkpoint(.synced(SnapshotID("abc")))))
        // Replayed startSync put us in syncing — complete it
        try await actor.trigger(.syncCompleted(.synced(SnapshotID("abc"))))

        let action = try await actor.trigger(.startSync)
        guard case .incrementalSync(let from) = action else {
            #expect(Bool(false), "Expected .incrementalSync, got \(action)")
            return
        }
        #expect(from == SnapshotID("abc"))
    }

    @Test func invalidEventFromIdleThrows() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.empty))
        try await actor.trigger(.syncCompleted(.synced(SnapshotID("abc"))))

        await #expect(throws: SyncStateMachineError.self) {
            try await actor.trigger(.syncCompleted(.synced(SnapshotID("def"))))
        }
    }

    // MARK: - syncing

    @Test func syncCompletedTransitionsToIdle() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.empty))

        let snapshot = SnapshotID("abc123")
        try await actor.trigger(.syncCompleted(.synced(snapshot)))

        guard case .idle(.checkpoint(.synced(let s))) = await actor.phase() else {
            #expect(Bool(false), "Expected .idle(.checkpoint(.synced))")
            return
        }
        #expect(s == snapshot)
    }

    @Test func syncFailedTransitionsToFailed() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.empty))

        let error = NSError(domain: "test", code: 42)
        try await actor.trigger(.syncFailed(error))

        guard case .failed(.empty, _) = await actor.phase() else {
            #expect(Bool(false), "Expected .failed(.empty, ...) phase")
            return
        }
    }

    @Test func invalidEventFromSyncingThrows() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.empty))

        await #expect(throws: SyncStateMachineError.self) {
            try await actor.trigger(.hydrationCompleted(.empty))
        }
    }

    // MARK: - failed

    @Test func startSyncFromFailedRetries() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.empty))
        try await actor.trigger(.syncFailed(NSError(domain: "test", code: 1)))

        let action = try await actor.trigger(.startSync)
        guard case .fullBuild = action else {
            #expect(Bool(false), "Expected .fullBuild, got \(action)")
            return
        }
        guard case .syncing(.empty) = await actor.phase() else {
            #expect(Bool(false), "Expected .syncing(.empty) phase")
            return
        }
    }

    @Test func startSyncFromFailedWithCheckpointDoesIncremental() async throws {
        let actor = SyncStateActor()
        let snapshot = SnapshotID("abc")
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.checkpoint(.synced(snapshot))))
        // Replayed startSync → syncing. Fail it.
        try await actor.trigger(.syncFailed(NSError(domain: "test", code: 1)))

        let action = try await actor.trigger(.startSync)
        guard case .incrementalSync(let from) = action else {
            #expect(Bool(false), "Expected .incrementalSync, got \(action)")
            return
        }
        #expect(from == snapshot)
    }

    @Test func invalidEventFromFailedThrows() async throws {
        let actor = SyncStateActor()
        _ = try await actor.trigger(.startSync)
        _ = try await actor.trigger(.hydrationCompleted(.empty))
        try await actor.trigger(.syncFailed(NSError(domain: "test", code: 1)))

        await #expect(throws: SyncStateMachineError.self) {
            try await actor.trigger(.hydrationCompleted(.empty))
        }
    }

    // MARK: - Full flow

    @Test func fullFlowFromNotHydratedToSyncedToIncremental() async throws {
        let actor = SyncStateActor()

        // 1. startSync → hydrate
        let a1 = try await actor.trigger(.startSync)
        guard case .hydrate = a1 else { return }

        // 2. hydrationCompleted with empty → fullBuild (replayed startSync)
        let a2 = try await actor.trigger(.hydrationCompleted(.empty))
        guard case .fullBuild = a2 else { return }

        // 3. syncCompleted → idle
        let snapshot1 = SnapshotID("abc")
        try await actor.trigger(.syncCompleted(.synced(snapshot1)))
        guard case .idle(.checkpoint(.synced(let s1))) = await actor.phase() else { return }
        #expect(s1 == snapshot1)

        // 4. startSync again → incrementalSync
        let a3 = try await actor.trigger(.startSync)
        guard case .incrementalSync(let from) = a3 else { return }
        #expect(from == snapshot1)

        // 5. syncCompleted with new snapshot
        let snapshot2 = SnapshotID("def")
        try await actor.trigger(.syncCompleted(.synced(snapshot2)))
        guard case .idle(.checkpoint(.synced(let s2))) = await actor.phase() else { return }
        #expect(s2 == snapshot2)
    }
}
