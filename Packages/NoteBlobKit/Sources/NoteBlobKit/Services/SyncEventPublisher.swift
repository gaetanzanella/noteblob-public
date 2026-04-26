import Foundation
import Synchronization

public enum SyncEvent: Sendable {
    case didPull(Folder)
    case didMerge(Folder)
    case didDiscard(Folder)
    case didDelete(Folder)
}

public final class SyncEventPublisher: Sendable {

    public final class Subscription: Sendable {
        private let id: UUID
        private let publisher: SyncEventPublisher

        fileprivate init(id: UUID, publisher: SyncEventPublisher) {
            self.id = id
            self.publisher = publisher
        }

        deinit {
            publisher.remove(id)
        }
    }

    private let handlers = Mutex<[UUID: @Sendable (SyncEvent) -> Void]>([:])

    public init() {}

    public func publish(_ event: SyncEvent) {
        let currentHandlers = handlers.withLock { $0 }
        for handler in currentHandlers.values {
            handler(event)
        }
    }

    public func subscribe(_ handler: @escaping @Sendable (SyncEvent) -> Void) -> Subscription {
        let id = UUID()
        handlers.withLock { $0[id] = handler }
        return Subscription(id: id, publisher: self)
    }

    private func remove(_ id: UUID) {
        handlers.withLock { $0[id] = nil }
    }
}
