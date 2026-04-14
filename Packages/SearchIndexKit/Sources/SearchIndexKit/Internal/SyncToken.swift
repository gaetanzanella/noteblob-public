import Foundation

struct SnapshotID: Sendable, Equatable {
    let value: String

    init(_ value: String) {
        self.value = value
    }
}
