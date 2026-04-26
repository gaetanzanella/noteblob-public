import Foundation
import SwiftGitX
import libgit2

extension SwiftGitXClient {

    // MARK: - Push

    func push(at localPath: URL) async throws {
        try await queue.enqueue(for: localPath) { [self] in
            let repo = try LibGit2Repository(at: localPath)

            try repo.withHead { headRef in
                guard let branchNamePtr = git_reference_shorthand(headRef) else {
                    throw GitClientError.commandFailed(
                        command: "push", output: "Cannot resolve HEAD branch name")
                }
                let branchName = String(cString: branchNamePtr)
                let refspec = "refs/heads/\(branchName):refs/heads/\(branchName)"

                var remotePtr: OpaquePointer?
                try gitCheck(git_remote_lookup(&remotePtr, repo.pointer, "origin"))
                defer { git_remote_free(remotePtr) }

                try refspec.withCString { refspecCStr in
                    let mutablePtr = UnsafeMutablePointer(mutating: refspecCStr)
                    var mutableOptional: UnsafeMutablePointer<CChar>? = mutablePtr
                    try withUnsafeMutablePointer(to: &mutableOptional) { stringsPtr in
                        var refspecs = git_strarray(strings: stringsPtr, count: 1)
                        try gitCheck(git_remote_push(remotePtr, &refspecs, nil))
                    }
                }
            }

            try setUpstreamIfNeeded(repo: repo)
        }
    }

    // MARK: - Pull (fetch + rebase)

    func pull(at localPath: URL) async throws {
        try await queue.enqueue(for: localPath) { [self] in
            // Fetch via SwiftGitX high-level API
            let swiftGitRepo = try SwiftGitX.Repository.open(at: localPath)
            try await swiftGitRepo.fetch()

            // Rebase via libgit2 C API
            let repo = try LibGit2Repository(at: localPath)
            try performRebaseWithUpstream(repo: repo)
        }
    }

    // MARK: - Remote Comparison

    func aheadBehind(at localPath: URL, defaultBranch: String) async throws -> (ahead: Int, behind: Int) {
        try await queue.enqueue(for: localPath) {
            let repo = try LibGit2Repository(at: localPath)

            return try repo.withHead { headRef in
                // Try upstream first; fall back to default branch for unpushed branches.
                var compareRef: OpaquePointer?
                var upstreamResult = git_branch_upstream(&compareRef, headRef)
                if upstreamResult < 0 {
                    upstreamResult = git_branch_lookup(
                        &compareRef, repo.pointer, defaultBranch, GIT_BRANCH_LOCAL)
                    if upstreamResult < 0 {
                        return (0, 0)
                    }
                }
                defer { git_reference_free(compareRef) }

                guard let localOID = git_reference_target(headRef),
                    let remoteOID = git_reference_target(compareRef)
                else {
                    return (0, 0)
                }

                var ahead = 0
                var behind = 0
                try gitCheck(
                    git_graph_ahead_behind(&ahead, &behind, repo.pointer, localOID, remoteOID))
                return (ahead: ahead, behind: behind)
            }
        }
    }

    // MARK: - Upstream

    func hasUpstream(at localPath: URL) async throws -> Bool {
        try await queue.enqueue(for: localPath) {
            let repo = try LibGit2Repository(at: localPath)
            return try repo.withHead { headRef in
                var upstreamRef: OpaquePointer?
                let result = git_branch_upstream(&upstreamRef, headRef)
                if result >= 0 {
                    git_reference_free(upstreamRef)
                    return true
                }
                return false
            }
        }
    }

    // MARK: - Private

    private func setUpstreamIfNeeded(repo: LibGit2Repository) throws {
        try repo.withHead { headRef in
            // Check if upstream already exists
            var upstreamRef: OpaquePointer?
            let result = git_branch_upstream(&upstreamRef, headRef)
            if result >= 0 {
                git_reference_free(upstreamRef)
                return
            }

            // Set upstream to origin/<branchName>
            var namePtr: UnsafePointer<CChar>?
            try gitCheck(git_branch_name(&namePtr, headRef))
            let branchName = String(cString: namePtr!)
            try gitCheck(git_branch_set_upstream(headRef, "origin/\(branchName)"))
        }
    }

    // MARK: - Rebase Implementation

    private func performRebaseWithUpstream(repo: LibGit2Repository) throws {
        let headRef = try repo.head()
        defer { git_reference_free(headRef) }

        var upstreamRef: OpaquePointer?
        try gitCheck(git_branch_upstream(&upstreamRef, headRef))
        defer { git_reference_free(upstreamRef) }

        guard let upstreamOID = git_reference_target(upstreamRef) else {
            throw GitClientError.commandFailed(
                command: "pull", output: "Cannot resolve upstream target")
        }

        var upstreamAnnotated: OpaquePointer?
        try gitCheck(git_annotated_commit_lookup(&upstreamAnnotated, repo.pointer, upstreamOID))
        defer { git_annotated_commit_free(upstreamAnnotated) }

        // Analyze to check if up-to-date or fast-forward
        var analysis = GIT_MERGE_ANALYSIS_NONE
        var preference = GIT_MERGE_PREFERENCE_NONE
        var theirHeads: OpaquePointer? = upstreamAnnotated
        try gitCheck(git_merge_analysis(&analysis, &preference, repo.pointer, &theirHeads, 1))

        if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
            return
        }

        if analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0 {
            try performFastForward(repo: repo, headRef: headRef, targetOID: upstreamOID)
            return
        }

        // Diverged: rebase local commits on top of upstream
        var rebase: OpaquePointer?
        var rebaseOpts = git_rebase_options()
        try gitCheck(git_rebase_options_init(&rebaseOpts, UInt32(GIT_REBASE_OPTIONS_VERSION)))

        try gitCheck(
            git_rebase_init(&rebase, repo.pointer, nil, upstreamAnnotated, nil, &rebaseOpts))
        defer { git_rebase_free(rebase) }

        var signature: UnsafeMutablePointer<git_signature>?
        try gitCheck(git_signature_default(&signature, repo.pointer))
        defer { git_signature_free(signature) }

        // Replay each commit
        var operation: UnsafeMutablePointer<git_rebase_operation>?
        while true {
            let result = git_rebase_next(&operation, rebase)

            if result == GIT_ITEROVER.rawValue {
                break
            }

            guard result >= 0 else {
                git_rebase_abort(rebase)
                throw GitClientError.conflict
            }

            // Check for conflicts in the index
            try repo.withIndex { index in
                if git_index_has_conflicts(index) != 0 {
                    git_rebase_abort(rebase)
                    throw GitClientError.conflict
                }
            }

            // Commit the rebased patch (NULL message = keep original message)
            var commitOID = git_oid()
            let commitResult = git_rebase_commit(&commitOID, rebase, nil, signature, nil, nil)

            if commitResult == GIT_EAPPLIED.rawValue {
                continue
            }

            guard commitResult >= 0 else {
                git_rebase_abort(rebase)
                let error = git_error_last()
                let message =
                    error.flatMap { String(cString: $0.pointee.message) } ?? "Unknown error"
                throw GitClientError.commandFailed(
                    command: "pull --rebase",
                    output: "Failed to commit rebased patch: \(message)")
            }
        }

        try gitCheck(git_rebase_finish(rebase, signature))
    }

    private func performFastForward(
        repo: LibGit2Repository, headRef: OpaquePointer,
        targetOID: UnsafePointer<git_oid>
    ) throws {
        var newRef: OpaquePointer?
        try gitCheck(git_reference_set_target(&newRef, headRef, targetOID, "pull: fast-forward"))
        defer { git_reference_free(newRef) }

        var checkoutOpts = try LibGit2Repository.checkoutOptions(
            strategy: GIT_CHECKOUT_FORCE.rawValue)
        try gitCheck(git_checkout_head(repo.pointer, &checkoutOpts))
    }
}
