import Foundation
import Testing
import libgit2

// MARK: - Standalone helpers (no project dependencies)

private func gitCheck(_ result: Int32) throws {
    guard result >= 0 else {
        let error = git_error_last()
        let message = error.flatMap { String(cString: $0.pointee.message) } ?? "Unknown libgit2 error"
        throw NSError(domain: "libgit2", code: Int(result), userInfo: [NSLocalizedDescriptionKey: message])
    }
}

/// Lists tracked file paths in the HEAD tree of the repo at `repoPath`.
private func trackedFiles(repoPtr: OpaquePointer) throws -> [String] {
    var headRef: OpaquePointer?
    try gitCheck(git_repository_head(&headRef, repoPtr))
    defer { git_reference_free(headRef) }

    guard let targetOID = git_reference_target(headRef) else { return [] }

    var commit: OpaquePointer?
    try gitCheck(git_commit_lookup(&commit, repoPtr, targetOID))
    defer { git_commit_free(commit) }

    var tree: OpaquePointer?
    try gitCheck(git_commit_tree(&tree, commit))
    defer { git_tree_free(tree) }

    var paths: [String] = []

    let callback: git_treewalk_cb = { root, entry, payload in
        guard let entry else { return 0 }
        let type = git_tree_entry_type(entry)
        guard type == GIT_OBJECT_BLOB else { return 0 }

        let name = String(cString: git_tree_entry_name(entry)!)
        let rootStr = root.map { String(cString: $0) } ?? ""
        let fullPath = rootStr + name

        let pathsPtr = payload!.assumingMemoryBound(to: [String].self)
        pathsPtr.pointee.append(fullPath)
        return 0
    }

    try withUnsafeMutablePointer(to: &paths) { ptr in
        try gitCheck(git_tree_walk(tree, GIT_TREEWALK_PRE, callback, ptr))
    }

    return paths
}

// MARK: - Approach 1: Single revwalk (batch)

/// Walks the commit history once and collects the last change date for every requested path.
private func lastChangeDates_singleWalk(
    repoPtr: OpaquePointer,
    paths: [String]
) throws -> [String: Date] {
    var remaining = Set(paths)
    var result: [String: Date] = [:]

    var walker: OpaquePointer?
    try gitCheck(git_revwalk_new(&walker, repoPtr))
    defer { git_revwalk_free(walker) }

    git_revwalk_sorting(walker, GIT_SORT_TIME.rawValue)
    try gitCheck(git_revwalk_push_head(walker))

    var oid = git_oid()
    while git_revwalk_next(&oid, walker) == 0, !remaining.isEmpty {
        var commit: OpaquePointer?
        guard git_commit_lookup(&commit, repoPtr, &oid) == 0 else { continue }
        defer { git_commit_free(commit) }

        var commitTree: OpaquePointer?
        try gitCheck(git_commit_tree(&commitTree, commit))
        defer { git_tree_free(commitTree) }

        // Get parent tree (nil for root commit)
        var parentTree: OpaquePointer?
        let parentCount = git_commit_parentcount(commit)
        if parentCount > 0 {
            var parent: OpaquePointer?
            try gitCheck(git_commit_parent(&parent, commit, 0))
            defer { git_commit_free(parent) }
            try gitCheck(git_commit_tree(&parentTree, parent))
        }
        defer { if parentTree != nil { git_tree_free(parentTree) } }

        // Diff parent..commit
        var diff: OpaquePointer?
        try gitCheck(git_diff_tree_to_tree(&diff, repoPtr, parentTree, commitTree, nil))
        defer { git_diff_free(diff) }

        let numDeltas = git_diff_num_deltas(diff)
        let time = git_commit_time(commit)
        let date = Date(timeIntervalSince1970: TimeInterval(time))

        for i in 0..<numDeltas {
            guard let delta = git_diff_get_delta(diff, i) else { continue }
            let newPath = String(cString: delta.pointee.new_file.path)
            if remaining.contains(newPath) {
                result[newPath] = date
                remaining.remove(newPath)
            }
            let oldPath = String(cString: delta.pointee.old_file.path)
            if oldPath != newPath, remaining.contains(oldPath) {
                result[oldPath] = date
                remaining.remove(oldPath)
            }
        }
    }

    return result
}

// MARK: - Approach 2: Per-file revwalk

/// For each path, walks the commit history independently to find the last commit that touched it.
private func lastChangeDates_perFile(
    repoPtr: OpaquePointer,
    paths: [String]
) throws -> [String: Date] {
    var result: [String: Date] = [:]

    for path in paths {
        var walker: OpaquePointer?
        try gitCheck(git_revwalk_new(&walker, repoPtr))
        defer { git_revwalk_free(walker) }

        git_revwalk_sorting(walker, GIT_SORT_TIME.rawValue)
        try gitCheck(git_revwalk_push_head(walker))

        var oid = git_oid()
        while git_revwalk_next(&oid, walker) == 0 {
            var commit: OpaquePointer?
            guard git_commit_lookup(&commit, repoPtr, &oid) == 0 else { continue }
            defer { git_commit_free(commit) }

            var commitTree: OpaquePointer?
            try gitCheck(git_commit_tree(&commitTree, commit))
            defer { git_tree_free(commitTree) }

            var parentTree: OpaquePointer?
            let parentCount = git_commit_parentcount(commit)
            if parentCount > 0 {
                var parent: OpaquePointer?
                try gitCheck(git_commit_parent(&parent, commit, 0))
                defer { git_commit_free(parent) }
                try gitCheck(git_commit_tree(&parentTree, parent))
            }
            defer { if parentTree != nil { git_tree_free(parentTree) } }

            var diff: OpaquePointer?
            try gitCheck(git_diff_tree_to_tree(&diff, repoPtr, parentTree, commitTree, nil))
            defer { git_diff_free(diff) }

            let numDeltas = git_diff_num_deltas(diff)
            var found = false
            for i in 0..<numDeltas {
                guard let delta = git_diff_get_delta(diff, i) else { continue }
                let newPath = String(cString: delta.pointee.new_file.path)
                let oldPath = String(cString: delta.pointee.old_file.path)
                if newPath == path || oldPath == path {
                    found = true
                    break
                }
            }

            if found {
                let time = git_commit_time(commit)
                result[path] = Date(timeIntervalSince1970: TimeInterval(time))
                break
            }
        }
    }

    return result
}

// MARK: - Tests

/// Provide the path to a git repository to benchmark against.
/// Defaults to the NoteBlobKit package repo (this repo).
private let testRepoPath: String = {
    // Walk up from Tests/NoteBlobKitTests/file.swift to the git root
    var url = URL(fileURLWithPath: #filePath)
    // Go up to: texteditor/ (the actual git repo root)
    for _ in 0..<5 { url = url.deletingLastPathComponent() }
    return url.path
}()

@Suite("Last change date performance comparison")
struct LastChangeDatePerfTests {

    @Test func singleWalkProducesSameResultsAsPerFile() throws {
        git_libgit2_init()
        defer { git_libgit2_shutdown() }

        var repoPtr: OpaquePointer?
        try gitCheck(git_repository_open(&repoPtr, testRepoPath))
        defer { git_repository_free(repoPtr) }

        let files = try trackedFiles(repoPtr: repoPtr!)
        guard !files.isEmpty else {
            Issue.record("No tracked files found in \(testRepoPath)")
            return
        }

        // Use a subset to keep the correctness test fast
        let subset = Array(files.prefix(10))

        let batchResult = try lastChangeDates_singleWalk(repoPtr: repoPtr!, paths: subset)
        let perFileResult = try lastChangeDates_perFile(repoPtr: repoPtr!, paths: subset)

        for path in subset {
            #expect(
                batchResult[path] == perFileResult[path],
                "Mismatch for \(path): batch=\(String(describing: batchResult[path])) perFile=\(String(describing: perFileResult[path]))"
            )
        }
    }

    @Test(arguments: [5, 10, 20, 125])
    func benchmark(fileCount: Int) throws {
        git_libgit2_init()
        defer { git_libgit2_shutdown() }

        var repoPtr: OpaquePointer?
        try gitCheck(git_repository_open(&repoPtr, testRepoPath))
        defer { git_repository_free(repoPtr) }

        let allFiles = try trackedFiles(repoPtr: repoPtr!)
        let files = Array(allFiles.prefix(fileCount))
        guard !files.isEmpty else { return }

        let startBatch = ContinuousClock.now
        let batchResult = try lastChangeDates_singleWalk(repoPtr: repoPtr!, paths: files)
        let batchElapsed = ContinuousClock.now - startBatch

        let startPerFile = ContinuousClock.now
        let perFileResult = try lastChangeDates_perFile(repoPtr: repoPtr!, paths: files)
        let perFileElapsed = ContinuousClock.now - startPerFile

        print("--- \(files.count) files ---")
        print("  Single walk: \(batchElapsed)")
        print("  Per-file:    \(perFileElapsed)")

        // Verify same results
        for path in files {
            #expect(batchResult[path] == perFileResult[path])
        }
    }
}
