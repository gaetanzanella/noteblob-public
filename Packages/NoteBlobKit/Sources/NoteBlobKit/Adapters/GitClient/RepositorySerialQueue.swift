import Foundation

/// Provides per-repository-path serial execution of async operations.
///
/// All operations targeting the same `localPath` are serialised, preventing
/// concurrent libgit2 calls from racing on the same on-disk repository.
/// Operations on *different* paths run independently.
actor RepositorySerialQueue {

  private var chains: [String: Task<Void, Never>] = [:]

  /// Execute `operation` serially with respect to other operations for the
  /// same canonical path.
  func enqueue<T: Sendable>(
    for localPath: URL,
    operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    let key = localPath.standardizedFileURL.path
    let previous = chains[key]
    let current = Task<T, any Error> {
      await previous?.value
      return try await operation()
    }
    chains[key] = Task { _ = await current.result }
    return try await current.value
  }
}
