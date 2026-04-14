import Foundation

enum SyncStateMachineError: Error {
    case invalidTransition(from: SyncStateActor.Phase, event: SyncStateActor.Event)
}

enum SyncCheckpoint: Sendable, Equatable {
    case synced(SnapshotID)
    case initializing(snapshot: SnapshotID, indexedCount: Int)
}

enum IndexState {
    case empty
    case checkpoint(SyncCheckpoint)
}

actor SyncStateActor {

    enum Phase {
        case notHydrated
        case hydrating(pendingEvent: Event?)
        case idle(IndexState)
        case syncing(IndexState)
        case failed(IndexState, error: Error)
    }

    enum Event {
        case startHydration
        case startSync
        case hydrationCompleted(IndexState)
        case hydrationFailed
        case syncCompleted(SyncCheckpoint)
        case syncFailed(Error)
    }

    enum Action {
        case hydrate
        case noop
        case fullBuild
        case resumeBuild(snapshot: SnapshotID, alreadyIndexed: Int)
        case incrementalSync(from: SnapshotID)
    }

    private var _phase: Phase = .notHydrated
    private var observers: [UUID: AsyncStream<Phase>.Continuation] = [:]

    func phase() -> Phase {
        _phase
    }

    func phaseStream() -> AsyncStream<Phase> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Phase.self)
        observers[id] = continuation
        continuation.yield(_phase)
        continuation.onTermination = { _ in
            Task { [weak self] in await self?.removeObserver(id: id) }
        }
        return stream
    }

    func trigger(_ event: Event) throws -> Action {
        switch _phase {
        case .notHydrated:
            switch event {
            case .startHydration:
                transition(to: .hydrating(pendingEvent: nil))
                return .hydrate
            case .startSync:
                transition(to: .hydrating(pendingEvent: .startSync))
                return .hydrate
            default:
                throw SyncStateMachineError.invalidTransition(from: _phase, event: event)
            }
        case .hydrating(let pendingEvent):
            switch event {
            case .hydrationCompleted(let indexState):
                transition(to: .idle(indexState))
                if let pendingEvent {
                    return try trigger(pendingEvent)
                }
                return .noop
            case .hydrationFailed:
                transition(to: .idle(.empty))
                if let pendingEvent {
                    return try trigger(pendingEvent)
                }
                return .noop
            default:
                throw SyncStateMachineError.invalidTransition(from: _phase, event: event)
            }
        case .idle(let indexState):
            switch event {
            case .startHydration:
                return .noop
            case .startSync:
                return try beginSync(from: indexState)
            default:
                throw SyncStateMachineError.invalidTransition(from: _phase, event: event)
            }
        case .syncing(let indexState):
            switch event {
            case .syncCompleted(let newCheckpoint):
                transition(to: .idle(.checkpoint(newCheckpoint)))
                return .noop
            case .syncFailed(let error):
                transition(to: .failed(indexState, error: error))
                return .noop
            default:
                throw SyncStateMachineError.invalidTransition(from: _phase, event: event)
            }
        case .failed(let indexState, _):
            switch event {
            case .startHydration:
                return .noop
            case .startSync:
                return try beginSync(from: indexState)
            default:
                throw SyncStateMachineError.invalidTransition(from: _phase, event: event)
            }
        }
    }

    // MARK: - Private

    private func removeObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }

    private func transition(to phase: Phase) {
        _phase = phase
        for continuation in observers.values {
            continuation.yield(phase)
        }
    }

    private func beginSync(from indexState: IndexState) throws -> Action {
        transition(to: .syncing(indexState))
        switch indexState {
        case .empty:
            return .fullBuild
        case .checkpoint(.synced(let snapshot)):
            return .incrementalSync(from: snapshot)
        case .checkpoint(.initializing(let snapshot, let indexedCount)):
            return .resumeBuild(snapshot: snapshot, alreadyIndexed: indexedCount)
        }
    }
}
