import Foundation

public enum NoteBlobError: Error, Equatable {
    case notAuthenticated
    case conflict
    case syncFailed(String)
    case mergeConflict(prURL: String)
    case invalidOperation(String)
}
