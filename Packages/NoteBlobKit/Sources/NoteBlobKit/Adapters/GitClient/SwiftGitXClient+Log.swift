import Foundation
import libgit2

extension SwiftGitXClient {

    // MARK: - Log

    func log(at localPath: URL, options: LogOptions)
        async throws -> [CommitInfo]
    {
        try await queue.enqueue(for: localPath) { [self] in
            let repo = try LibGit2Repository(at: localPath)

            var walker: OpaquePointer?
            try gitCheck(git_revwalk_new(&walker, repo.pointer))
            defer { git_revwalk_free(walker) }

            git_revwalk_sorting(walker, GIT_SORT_TIME.rawValue | GIT_SORT_TOPOLOGICAL.rawValue)
            try gitCheck(git_revwalk_push_head(walker))

            // Hide commits reachable from the given ref
            if let downToRef = options.downToRef {
                var oid = git_oid()
                // Try as a ref name (branch, tag, etc.), then as a raw SHA
                var ref: OpaquePointer?
                if git_reference_dwim(&ref, repo.pointer, downToRef) == 0 {
                    defer { git_reference_free(ref) }
                    if let refOID = git_reference_target(ref) {
                        git_revwalk_hide(walker, refOID)
                    }
                } else if git_oid_fromstr(&oid, downToRef) == 0 {
                    git_revwalk_hide(walker, &oid)
                }
            }

            var commits: [CommitInfo] = []
            var oid = git_oid()
            var uniqueFiles = Set<String>()
            let path = options.path?.value
            let needsChangedFiles = options.uniqueFilesLimit != nil
            while git_revwalk_next(&oid, walker) == 0, commits.count < options.limit {
                var commit: OpaquePointer?
                guard git_commit_lookup(&commit, repo.pointer, &oid) == 0 else { continue }
                defer { git_commit_free(commit) }

                // When filtering by path, use early-exit check
                if let path, !needsChangedFiles {
                    guard try commitTouchesPath(commit!, repo: repo, path: path) else { continue }
                }

                let changedFiles =
                    needsChangedFiles
                    ? try commitChangedFiles(commit!, repo: repo)
                    : []

                // When filtering by path with changed files collection
                if let path, needsChangedFiles {
                    guard changedFiles.contains(path) else { continue }
                }

                // Short hash
                let fullHash = String(cString: git_oid_tostr_s(&oid))
                let shortHash = String(fullHash.prefix(7))

                // Message (first line)
                let message: String
                if let msgPtr = git_commit_message(commit) {
                    let full = String(cString: msgPtr)
                    message = full.components(separatedBy: .newlines).first ?? full
                } else {
                    message = ""
                }

                // Date
                let time = git_commit_time(commit)
                let date = Date(timeIntervalSince1970: TimeInterval(time))

                commits.append(
                    CommitInfo(
                        id: shortHash, message: message, date: date, changedFiles: changedFiles))

                // Stop if we've collected enough unique files
                if let uniqueFilesLimit = options.uniqueFilesLimit {
                    uniqueFiles.formUnion(changedFiles)
                    if uniqueFiles.count >= uniqueFilesLimit { break }
                }
            }

            return commits
        }
    }

    // MARK: - Private

    private func commitTouchesPath(
        _ commit: OpaquePointer, repo: LibGit2Repository, path: String
    ) throws -> Bool {
        var commitTree: OpaquePointer?
        try gitCheck(git_commit_tree(&commitTree, commit))
        defer { git_tree_free(commitTree) }

        var parentTree: OpaquePointer?
        if git_commit_parentcount(commit) > 0 {
            var parent: OpaquePointer?
            try gitCheck(git_commit_parent(&parent, commit, 0))
            defer { git_commit_free(parent) }
            try gitCheck(git_commit_tree(&parentTree, parent))
        }
        defer { if parentTree != nil { git_tree_free(parentTree) } }

        var diff: OpaquePointer?
        try gitCheck(git_diff_tree_to_tree(&diff, repo.pointer, parentTree, commitTree, nil))
        defer { git_diff_free(diff) }

        let numDeltas = git_diff_num_deltas(diff)
        for i in 0..<numDeltas {
            guard let delta = git_diff_get_delta(diff, i) else { continue }
            let newPath = String(cString: delta.pointee.new_file.path)
            let oldPath = String(cString: delta.pointee.old_file.path)
            if newPath == path || oldPath == path {
                return true
            }
        }
        return false
    }

    private func commitChangedFiles(
        _ commit: OpaquePointer, repo: LibGit2Repository
    ) throws -> [String] {
        var commitTree: OpaquePointer?
        try gitCheck(git_commit_tree(&commitTree, commit))
        defer { git_tree_free(commitTree) }

        var parentTree: OpaquePointer?
        if git_commit_parentcount(commit) > 0 {
            var parent: OpaquePointer?
            try gitCheck(git_commit_parent(&parent, commit, 0))
            defer { git_commit_free(parent) }
            try gitCheck(git_commit_tree(&parentTree, parent))
        }
        defer { if parentTree != nil { git_tree_free(parentTree) } }

        var diff: OpaquePointer?
        try gitCheck(git_diff_tree_to_tree(&diff, repo.pointer, parentTree, commitTree, nil))
        defer { git_diff_free(diff) }

        var files: [String] = []
        let numDeltas = git_diff_num_deltas(diff)
        for i in 0..<numDeltas {
            guard let delta = git_diff_get_delta(diff, i) else { continue }
            let newPath = String(cString: delta.pointee.new_file.path)
            files.append(newPath)
        }
        return files
    }
}
