import Foundation

protocol SnapshotSource: Sendable {
    func currentSnapshot() async throws -> SnapshotID
    func allFiles(at snapshot: SnapshotID) async throws -> [FilePath]
    func fileContent(at snapshot: SnapshotID, path: FilePath) async throws -> String
    func diff(from: SnapshotID, to: SnapshotID) async throws -> [FileChange]
}

extension SearchIndexer.Strategy {
    func makeSnapshotSource() -> SnapshotSource {
        switch self {
        case .git(let options):
            return GitSnapshotSource(
                gitProtocol: options.gitProtocol,
                defaultBranch: options.defaultBranch
            )
        }
    }
}
