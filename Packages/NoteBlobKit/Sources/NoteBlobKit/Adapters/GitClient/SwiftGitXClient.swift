import Foundation
import SwiftGitX
import libgit2

// Typealias to disambiguate from our own Repository model
private typealias GitRepo = SwiftGitX.Repository

final class SwiftGitXClient: GitClient, Sendable {

    let queue = RepositorySerialQueue()

    init() {}

    // MARK: - Clone

    func clone(remoteURL: String, to localPath: URL) async throws {
        try await queue.enqueue(for: localPath) {
            let parent = localPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            guard let url = URL(string: remoteURL) else {
                throw GitClientError.commandFailed(
                    command: "clone", output: "Invalid URL: \(remoteURL)")
            }
            _ = try await GitRepo.clone(from: url, to: localPath)
        }
    }

    // MARK: - Fetch

    func fetch(at localPath: URL) async throws {
        try await queue.enqueue(for: localPath) {
            let repo = try GitRepo.open(at: localPath)
            try await repo.fetch()
        }
    }

    // MARK: - Status

    func pendingChanges(at localPath: URL) async throws -> [Change] {
        try await queue.enqueue(for: localPath) {
            let repo = try GitRepo.open(at: localPath)
            let entries = try repo.status()

            var changes: [Change] = []
            for entry in entries {
                let path = entry.index?.newFile.path ?? entry.workingTree?.newFile.path ?? ""
                guard !path.isEmpty else { continue }

                for status in entry.status {
                    switch status {
                    case .indexNew, .workingTreeNew:
                        changes.append(.added(path: path))
                    case .indexModified, .workingTreeModified:
                        changes.append(.modified(path: path))
                    case .indexDeleted, .workingTreeDeleted:
                        changes.append(.deleted(path: path))
                    default:
                        break
                    }
                }
            }

            // Deduplicate by path, preferring first occurrence
            var seen = Set<String>()
            return changes.filter { seen.insert($0.path).inserted }
        }
    }

    // MARK: - Commit

    func commitAll(at localPath: URL, message: String) async throws {
        try await queue.enqueue(for: localPath) { [self] in
            let repo = try GitRepo.open(at: localPath)
            try ensureIdentity(repo)

            let entries = try repo.status()
            for entry in entries {
                for status in entry.status {
                    switch status {
                    case .workingTreeNew, .workingTreeModified, .workingTreeDeleted:
                        if let path = entry.workingTree?.newFile.path {
                            try repo.add(path: path)
                        }
                    default:
                        break
                    }
                }
            }

            try repo.commit(message: message)
        }
    }

    // MARK: - Diff

    func diff(at localPath: URL, path: String) async throws -> FileDiff {
        try await queue.enqueue(for: localPath) { [self] in
            let repo = try GitRepo.open(at: localPath)

            // First try the combined HEAD→workdir diff (covers tracked files)
            let diff = try repo.diff(to: [.workingTree, .index])
            if let patch = diff.patches.first(where: {
                $0.delta.newFile.path == path || $0.delta.oldFile.path == path
            }) {
                return mapPatch(patch, path: path)
            }

            // For untracked (new) files, find the delta via status and build a patch
            let entries = try repo.status()
            for entry in entries {
                let entryPath = entry.index?.newFile.path ?? entry.workingTree?.newFile.path ?? ""
                guard entryPath == path else { continue }

                if let delta = entry.workingTree, let patch = try repo.patch(from: delta) {
                    return mapPatch(patch, path: path)
                }
                if let delta = entry.index, let patch = try repo.patch(from: delta) {
                    return mapPatch(patch, path: path)
                }
            }

            return FileDiff(path: path, hunks: [])
        }
    }

    // MARK: - Private Helpers

    private func ensureIdentity(_ repo: GitRepo) throws {
        let hasName = (try? repo.config.string(forKey: "user.name")) != nil
        let hasEmail = (try? repo.config.string(forKey: "user.email")) != nil
        if !hasName {
            try repo.config.set("user.name", to: "NoteBlob")
        }
        if !hasEmail {
            try repo.config.set("user.email", to: "noteblob@noreply")
        }
    }

    private func mapPatch(_ patch: SwiftGitX.Patch, path: String) -> FileDiff {
        let hunks = patch.hunks.map { hunk in
            FileDiff.Hunk(
                header: hunk.header,
                lines: hunk.lines.compactMap { line in
                    let kind: FileDiff.Hunk.Line.Kind? =
                        switch line.type {
                        case .context, .contextEOF: .context
                        case .addition, .additionEOF: .addition
                        case .deletion, .deletionEOF: .deletion
                        }
                    guard let kind else { return nil }
                    return FileDiff.Hunk.Line(kind: kind, content: line.content)
                }
            )
        }
        return FileDiff(path: path, hunks: hunks)
    }
}
