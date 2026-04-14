import Foundation

public enum NoteBlobError: Error, LocalizedError, Equatable {
    case notAuthenticated
    case conflict
    case syncFailed(String)
    case mergeConflict(prURL: String)
    case invalidOperation(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .conflict:
            return "Merge conflict detected. Resolve conflicts before continuing."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .mergeConflict(let prURL):
            return "Merge conflict on pull request. Resolve manually: \(prURL)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        }
    }
}
