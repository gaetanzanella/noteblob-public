import Foundation
import SearchIndexKit

/// GitProtocol implementation backed by the git CLI. Used in integration tests only.
final class CLIGitProtocol: GitProtocol {

    private let localURL: URL

    init(localURL: URL) {
        self.localURL = localURL
    }

    func commitHash(ref: GitRef) async throws -> String {
        try shell("git rev-parse \(ref.value)", at: localURL).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func listFiles(ref: GitRef) async throws -> [String] {
        let output = try shell("git ls-tree -r --name-only \(ref.value)", at: localURL)
        return output
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    func showFile(ref: GitRef, path: FilePath) async throws -> String {
        try shell("git show \(ref.value):\(path)", at: localURL)
    }

    func diff(from: GitRef, to: GitRef) async throws -> [FileChange] {
        let output = try shell("git diff --name-status \(from.value)..\(to.value)", at: localURL)
        return output
            .split(separator: "\n")
            .compactMap { line -> FileChange? in
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let status = parts[0]
                let path = String(parts[1])
                switch status {
                case "A":
                    return .added(path)
                case "M":
                    return .modified(path)
                case "D":
                    return .deleted(path)
                default:
                    return nil
                }
            }
    }
}

