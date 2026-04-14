import Foundation
import libgit2

/// RAII wrapper around a raw libgit2 repository pointer.
/// Frees the pointer automatically on deinit.
final class LibGit2Repository {

    private static let initOnce: Void = { git_libgit2_init() }()

    let pointer: OpaquePointer

    init(at url: URL) throws {
        _ = Self.initOnce
        var ptr: OpaquePointer?
        try gitCheck(git_repository_open(&ptr, url.path))
        self.pointer = ptr!
    }

    deinit { git_repository_free(pointer) }

    // MARK: - HEAD

    /// Returns the HEAD reference. Caller must free with `git_reference_free`.
    func head() throws -> OpaquePointer {
        var ref: OpaquePointer?
        try gitCheck(git_repository_head(&ref, pointer))
        return ref!
    }

    /// Executes a closure with the HEAD reference, freeing it automatically.
    func withHead<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        let ref = try head()
        defer { git_reference_free(ref) }
        return try body(ref)
    }

    /// Executes a closure with the HEAD commit tree, freeing intermediates automatically.
    func withHeadTree<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try withHead { headRef in
            guard let targetOID = git_reference_target(headRef) else {
                throw GitClientError.commandFailed(
                    command: "head", output: "Cannot resolve HEAD target")
            }
            var commit: OpaquePointer?
            try gitCheck(git_commit_lookup(&commit, pointer, targetOID))
            defer { git_commit_free(commit) }
            var tree: OpaquePointer?
            try gitCheck(git_commit_tree(&tree, commit))
            defer { git_tree_free(tree) }
            return try body(tree!)
        }
    }

    // MARK: - Index

    /// Executes a closure with the repository index, freeing it automatically.
    func withIndex<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        var idx: OpaquePointer?
        try gitCheck(git_repository_index(&idx, pointer))
        defer { git_index_free(idx) }
        return try body(idx!)
    }

    // MARK: - Checkout

    /// Creates a `git_checkout_options` with the given strategy.
    static func checkoutOptions(strategy: UInt32) throws -> git_checkout_options {
        var opts = git_checkout_options()
        try gitCheck(git_checkout_options_init(&opts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION)))
        opts.checkout_strategy = strategy
        return opts
    }
}
