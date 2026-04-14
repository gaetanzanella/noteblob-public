import Foundation
import SearchIndexKit

final class MockGitProtocol: GitProtocol, @unchecked Sendable {

    var commitHashes: [String: String] = [:]
    var files: [String: [String]] = [:]
    var fileContents: [String: [String: String]] = [:]
    var diffChanges: [FileChange] = []

    var commitHashCallCount = 0
    var listFilesCallCount = 0
    var showFileCallCount = 0
    var diffCallCount = 0

    var shouldThrow: Error?

    func commitHash(ref: GitRef) async throws -> String {
        commitHashCallCount += 1
        if let error = shouldThrow { throw error }
        guard let hash = commitHashes[ref.value] else {
            throw MockGitError.refNotFound
        }
        return hash
    }

    func listFiles(ref: GitRef) async throws -> [String] {
        listFilesCallCount += 1
        if let error = shouldThrow { throw error }
        // Try direct ref, then resolve ref as a branch name to its hash
        if let result = files[ref.value] { return result }
        let resolved = resolvedRef(ref)
        return files[resolved] ?? []
    }

    func showFile(ref: GitRef, path: FilePath) async throws -> String {
        showFileCallCount += 1
        if let error = shouldThrow { throw error }
        if let content = fileContents[ref.value]?[path] { return content }
        let resolved = resolvedRef(ref)
        guard let content = fileContents[resolved]?[path] else {
            throw MockGitError.fileNotFound
        }
        return content
    }

    /// If the ref is a commit hash, find which branch it belongs to and return that branch name.
    private func resolvedRef(_ ref: GitRef) -> String {
        for (branch, hash) in commitHashes where hash == ref.value {
            return branch
        }
        return ref.value
    }

    func diff(from: GitRef, to: GitRef) async throws -> [FileChange] {
        diffCallCount += 1
        if let error = shouldThrow { throw error }
        return diffChanges
    }
}

enum MockGitError: Error {
    case refNotFound
    case fileNotFound
}
