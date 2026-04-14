import Foundation

public enum Change: Sendable, Hashable {
    case added(path: String)
    case modified(path: String)
    case deleted(path: String)

    public var path: String {
        switch self {
        case .added(let path): return path
        case .modified(let path): return path
        case .deleted(let path): return path
        }
    }
}
