import Foundation

protocol RepositoryAdapter: Sendable {
    func cloneRepository(_ folder: Folder, credentials: Credentials) async throws
    func pull(_ folder: Folder) async throws
    func push(_ folder: Folder) async throws
    func pendingChanges(for folder: Folder) async throws -> [Change]
    func commitAll(in folder: Folder, message: String) async throws
    func currentBranch(for folder: Folder) async throws -> BranchInfo
    func createBranchAndSwitch(named: String, in folder: Folder) async throws
    func switchBranch(to name: String, in folder: Folder) async throws
    func deleteBranch(named: String, in folder: Folder) async throws
    func fetch(_ folder: Folder) async throws
    func aheadBehind(for folder: Folder, defaultBranch: String) async throws -> (ahead: Int, behind: Int)
    func hasUpstream(for folder: Folder) async throws -> Bool
    func discardChanges(in folder: Folder) async throws
    func discardChange(in folder: Folder, path: RelativePath) async throws
    func diff(for folder: Folder, path: RelativePath) async throws -> FileDiff
    func log(for folder: Folder, options: LogOptions) async throws -> [CommitInfo]
}
