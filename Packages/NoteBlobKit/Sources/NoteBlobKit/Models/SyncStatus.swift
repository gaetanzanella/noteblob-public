import Foundation

public enum SyncState: Sendable, Equatable {
    case upToDate
    case localChanges(Int)
    case pullNeeded
    case pushNeeded
    case readyToMerge
    case notBacked
}

public struct SyncStatus: Sendable, Equatable {
    public let state: SyncState
    public let branch: BranchInfo
}
