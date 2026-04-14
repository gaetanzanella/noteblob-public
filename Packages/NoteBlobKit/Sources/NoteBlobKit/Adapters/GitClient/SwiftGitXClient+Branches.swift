import Foundation
import libgit2

extension SwiftGitXClient {

    // MARK: - Current Branch

    func currentBranch(at localPath: URL) async throws -> BranchInfo {
        try await queue.enqueue(for: localPath) {
            let repo = try LibGit2Repository(at: localPath)
            return try repo.withHead { headRef in
                guard git_reference_is_branch(headRef) != 0 else {
                    throw GitClientError.commandFailed(
                        command: "currentBranch", output: "HEAD is not a branch")
                }
                var namePtr: UnsafePointer<CChar>?
                try gitCheck(git_branch_name(&namePtr, headRef))
                return BranchInfo(name: String(cString: namePtr!))
            }
        }
    }

    // MARK: - Create Branch

    func createBranch(named name: String, at localPath: URL) async throws {
        try await queue.enqueue(for: localPath) { [self] in
            let repo = try LibGit2Repository(at: localPath)

            try repo.withHead { headRef in
                guard let targetOID = git_reference_target(headRef) else {
                    throw GitClientError.commandFailed(
                        command: "createBranch", output: "Cannot resolve HEAD target")
                }

                var commit: OpaquePointer?
                try gitCheck(git_commit_lookup(&commit, repo.pointer, targetOID))
                defer { git_commit_free(commit) }

                var branchRef: OpaquePointer?
                try gitCheck(git_branch_create(&branchRef, repo.pointer, name, commit, 0))
                git_reference_free(branchRef)
            }

            try switchBranchRaw(repo: repo, branchName: name)
        }
    }

    // MARK: - Switch Branch

    func switchBranch(to name: String, at localPath: URL) async throws {
        try await queue.enqueue(for: localPath) { [self] in
            let repo = try LibGit2Repository(at: localPath)
            try switchBranchRaw(repo: repo, branchName: name)
        }
    }

    // MARK: - Delete Branch

    func deleteBranch(named name: String, at localPath: URL) async throws {
        try await queue.enqueue(for: localPath) {
            let repo = try LibGit2Repository(at: localPath)

            var branchRef: OpaquePointer?
            try gitCheck(git_branch_lookup(&branchRef, repo.pointer, name, GIT_BRANCH_LOCAL))
            defer { git_reference_free(branchRef) }

            try gitCheck(git_branch_delete(branchRef))
        }
    }

    // MARK: - Private

    private func switchBranchRaw(repo: LibGit2Repository, branchName: String) throws {
        let refName = "refs/heads/\(branchName)"

        var ref: OpaquePointer?
        try gitCheck(git_reference_lookup(&ref, repo.pointer, refName))
        defer { git_reference_free(ref) }

        guard let targetOID = git_reference_target(ref) else {
            throw GitClientError.commandFailed(
                command: "switchBranch", output: "Cannot resolve branch target")
        }

        var commit: OpaquePointer?
        try gitCheck(git_commit_lookup(&commit, repo.pointer, targetOID))
        defer { git_commit_free(commit) }

        var tree: OpaquePointer?
        try gitCheck(git_commit_tree(&tree, commit))
        defer { git_tree_free(tree) }

        var checkoutOpts = try LibGit2Repository.checkoutOptions(
            strategy: GIT_CHECKOUT_SAFE.rawValue)
        try gitCheck(git_checkout_tree(repo.pointer, tree, &checkoutOpts))
        try gitCheck(git_repository_set_head(repo.pointer, refName))
    }
}
