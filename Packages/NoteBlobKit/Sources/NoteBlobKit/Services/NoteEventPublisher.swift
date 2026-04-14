import Foundation
import Synchronization

public enum NoteEvent: Sendable {
    case didDelete(Folder, RelativePath)
}

public final class NoteEventPublisher: Sendable {

    public final class Subscription: Sendable {
        private let id: UUID
        private let publisher: NoteEventPublisher

        fileprivate init(id: UUID, publisher: NoteEventPublisher) {
            self.id = id
            self.publisher = publisher
        }

        deinit {
            publisher.remove(id)
        }
    }

    private let handlers = Mutex<[UUID: @Sendable (NoteEvent) -> Void]>([:])

    public init() {}

    public func publish(_ event: NoteEvent) {
        let currentHandlers = handlers.withLock { $0 }
        for handler in currentHandlers.values {
            handler(event)
        }
    }

    public func subscribe(_ handler: @escaping @Sendable (NoteEvent) -> Void) -> Subscription {
        let id = UUID()
        handlers.withLock { $0[id] = handler }
        return Subscription(id: id, publisher: self)
    }

    private func remove(_ id: UUID) {
        handlers.withLock { $0[id] = nil }
    }
}
