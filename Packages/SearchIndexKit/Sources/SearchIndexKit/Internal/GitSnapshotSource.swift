import Foundation

struct GitSnapshotSource: SnapshotSource {

    let gitProtocol: GitProtocol
    let defaultBranch: String

    func currentSnapshot() async throws -> SnapshotID {
        let hash = try await gitProtocol.commitHash(ref: GitRef(defaultBranch))
        return SnapshotID(hash)
    }

    func allFiles(at snapshot: SnapshotID) async throws -> [FilePath] {
        try await gitProtocol.listFiles(ref: GitRef(snapshot.value))
    }

    func fileContent(at snapshot: SnapshotID, path: FilePath) async throws -> String {
        try await gitProtocol.showFile(ref: GitRef(snapshot.value), path: path)
    }

    func diff(from: SnapshotID, to: SnapshotID) async throws -> [FileChange] {
        try await gitProtocol.diff(from: GitRef(from.value), to: GitRef(to.value))
    }
}
