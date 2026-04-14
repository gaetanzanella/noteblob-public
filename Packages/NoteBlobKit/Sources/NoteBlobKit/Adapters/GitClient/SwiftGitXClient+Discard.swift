import Foundation
import libgit2

extension SwiftGitXClient {

    // MARK: - Discard All Changes

    func discardChanges(at localPath: URL) async throws {
        try await queue.enqueue(for: localPath) {
            let repo = try LibGit2Repository(at: localPath)

            try repo.withHeadTree { tree in
                // Force-checkout HEAD tree to discard all working tree changes
                var checkoutOpts = try LibGit2Repository.checkoutOptions(
                    strategy: GIT_CHECKOUT_FORCE.rawValue | GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue)
                try gitCheck(git_checkout_tree(repo.pointer, tree, &checkoutOpts))

                // Reset the index to match HEAD
                try repo.withIndex { index in
                    try gitCheck(git_index_read_tree(index, tree))
                    try gitCheck(git_index_write(index))
                }
            }
        }
    }

    // MARK: - Discard Single File

    func discardChange(at localPath: URL, path: String) async throws {
        try await queue.enqueue(for: localPath) { [self] in
            let repo = try LibGit2Repository(at: localPath)

            // Check if HEAD exists (repository may have no commits yet)
            var headRef: OpaquePointer?
            let headResult = git_repository_head(&headRef, repo.pointer)

            guard headResult == 0, let headRef else {
                // No HEAD — just delete the file
                try FileManager.default.removeItem(at: localPath.appendingPathComponent(path))
                return
            }
            defer { git_reference_free(headRef) }

            guard let targetOID = git_reference_target(headRef) else {
                throw GitClientError.commandFailed(
                    command: "discardChange", output: "Cannot resolve HEAD target")
            }

            var commit: OpaquePointer?
            try gitCheck(git_commit_lookup(&commit, repo.pointer, targetOID))
            defer { git_commit_free(commit) }

            var tree: OpaquePointer?
            try gitCheck(git_commit_tree(&tree, commit))
            defer { git_tree_free(tree) }

            // Check if file exists in HEAD
            var entry: OpaquePointer?
            let findResult = path.withCString { git_tree_entry_bypath(&entry, tree, $0) }

            if findResult == 0 {
                defer { git_tree_entry_free(entry) }
                // Tracked file — checkout from HEAD and reset index
                try checkoutFileFromHEAD(repo: repo, tree: tree!, path: path)
            } else {
                // Untracked file — delete it
                try FileManager.default.removeItem(at: localPath.appendingPathComponent(path))
            }
        }
    }

    // MARK: - Private

    private func checkoutFileFromHEAD(
        repo: LibGit2Repository, tree: OpaquePointer, path: String
    ) throws {
        let cStr = strdup(path)!
        defer { free(cStr) }
        var pathPtr: UnsafeMutablePointer<CChar>? = cStr

        var checkoutOpts = try LibGit2Repository.checkoutOptions(
            strategy: GIT_CHECKOUT_FORCE.rawValue)
        try withUnsafeMutablePointer(to: &pathPtr) { ptr in
            checkoutOpts.paths.strings = ptr
            checkoutOpts.paths.count = 1
            try gitCheck(git_checkout_tree(repo.pointer, tree, &checkoutOpts))
        }

        // Update index for this file
        try repo.withIndex { index in
            try gitCheck(git_index_read_tree(index, tree))
            try gitCheck(git_index_write(index))
        }
    }
}
