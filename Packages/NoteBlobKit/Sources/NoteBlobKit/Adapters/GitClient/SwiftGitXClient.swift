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

            // Stage and commit through a single raw libgit2 handle.
            // SwiftGitX's index remove is internal, so we use libgit2
            // directly for the whole operation to avoid index cache conflicts.
            try stageAndCommit(at: localPath, entries: entries, message: message)
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

    private func stageAndCommit(
        at localPath: URL,
        entries: some Sequence<SwiftGitX.StatusEntry>,
        message: String
    ) throws {
        var repoPointer: OpaquePointer?
        guard git_repository_open(&repoPointer, localPath.path) == 0, let repoPointer else {
            throw GitClientError.commandFailed(command: "commit", output: "Failed to open repository")
        }
        defer { git_repository_free(repoPointer) }

        var indexPointer: OpaquePointer?
        guard git_repository_index(&indexPointer, repoPointer) == 0, let indexPointer else {
            throw GitClientError.commandFailed(command: "commit", output: "Failed to read index")
        }
        defer { git_index_free(indexPointer) }

        for entry in entries {
            for status in entry.status {
                guard let path = entry.workingTree?.newFile.path else { continue }
                switch status {
                case .workingTreeNew, .workingTreeModified:
                    git_index_add_bypath(indexPointer, path)
                case .workingTreeDeleted:
                    git_index_remove_bypath(indexPointer, path)
                default:
                    break
                }
            }
        }
        git_index_write(indexPointer)

        var oid = git_oid()
        var options = git_commit_create_options()
        options.version = UInt32(GIT_COMMIT_CREATE_OPTIONS_VERSION)
        let result = git_commit_create_from_stage(&oid, repoPointer, message, &options)
        guard result == 0 else {
            let errorMessage = String(cString: git_error_last().pointee.message)
            throw GitClientError.commandFailed(command: "commit", output: errorMessage)
        }
    }

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
