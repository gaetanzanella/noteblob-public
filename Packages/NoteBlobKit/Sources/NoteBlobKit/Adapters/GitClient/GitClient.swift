import Foundation

protocol GitClient: Sendable {
    func clone(remoteURL: String, to localPath: URL) async throws
    func pull(at localPath: URL) async throws
    func push(at localPath: URL) async throws
    func fetch(at localPath: URL) async throws
    func aheadBehind(at localPath: URL) async throws -> (ahead: Int, behind: Int)
    func pendingChanges(at localPath: URL) async throws -> [Change]
    func commitAll(at localPath: URL, message: String) async throws
    func currentBranch(at localPath: URL) async throws -> BranchInfo
    func createBranch(named: String, at localPath: URL) async throws
    func switchBranch(to name: String, at localPath: URL) async throws
    func deleteBranch(named: String, at localPath: URL) async throws
    func hasUpstream(at localPath: URL) async throws -> Bool
    func discardChanges(at localPath: URL) async throws
    func discardChange(at localPath: URL, path: String) async throws
    func diff(at localPath: URL, path: String) async throws -> FileDiff
    func log(at localPath: URL, options: LogOptions) async throws -> [CommitInfo]
}
