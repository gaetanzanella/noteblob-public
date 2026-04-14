import Foundation

public protocol GitProtocol: Sendable {
    func commitHash(ref: GitRef) async throws -> String
    func listFiles(ref: GitRef) async throws -> [String]
    func showFile(ref: GitRef, path: FilePath) async throws -> String
    func diff(from: GitRef, to: GitRef) async throws -> [FileChange]
}

public struct GitRef: Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public typealias FilePath = String

public enum FileChange: Sendable {
    case added(FilePath)
    case modified(FilePath)
    case deleted(FilePath)
}
