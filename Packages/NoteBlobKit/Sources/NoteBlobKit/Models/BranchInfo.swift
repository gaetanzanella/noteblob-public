import Foundation

public struct BranchInfo: Sendable, Equatable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}
