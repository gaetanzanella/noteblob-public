import Foundation

public struct BranchInfo: Sendable, Equatable {
    public let name: String
    public let isMain: Bool

    public init(name: String) {
        self.name = name
        self.isMain = name == "main" || name == "master"
    }
}
