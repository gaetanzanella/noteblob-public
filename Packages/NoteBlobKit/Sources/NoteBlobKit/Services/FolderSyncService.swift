import Foundation
import Synchronization

public final class FolderSyncService: Sendable {

    private let userRepository: UserRepository
    private let folderRepository: FolderRepository
    private let repositoryAdapter: RepositoryAdapter
    private let pullRequestAdapter: PullRequestAdapter
    private let eventPublisher: SyncEventPublisher

    private let cachedStatus = Mutex<[String: SyncStatus]>([:])

    init(
        userRepository: UserRepository,
        folderRepository: FolderRepository,
        repositoryAdapter: RepositoryAdapter,
        pullRequestAdapter: PullRequestAdapter,
        eventPublisher: SyncEventPublisher
    ) {
        self.userRepository = userRepository
        self.folderRepository = folderRepository
        self.repositoryAdapter = repositoryAdapter
        self.pullRequestAdapter = pullRequestAdapter
        self.eventPublisher = eventPublisher
    }

    public func lastStatus(for folder: Folder) -> SyncStatus? {
        cachedStatus.withLock { $0[folder.id] }
    }

    // MARK: - Folder management

    public func syncedFolders() throws -> [Folder] {
        try folderRepository.list()
    }

    public func searchFolders(query: String) async throws -> [Folder] {
        let credentials = try credentials()
        return try await userRepository.searchRepositories(query: query, credentials: credentials)
            .map(Folder.init(repository:))
    }

    public func add(_ folder: Folder) async throws {
        if folder.isGitBacked {
            let credentials = try credentials()
            try await repositoryAdapter.cloneRepository(folder, credentials: credentials)
        } else {
            try folderRepository.add(folder)
        }
    }

    public func remove(_ folder: Folder) throws {
        try folderRepository.remove(folder)
    }

    // MARK: - Sync

    public func status(for folder: Folder) async throws -> SyncStatus {
        guard folder.isGitBacked else {
            return SyncStatus(state: .notBacked, branch: BranchInfo(name: "local"))
        }

        let changes = try await repositoryAdapter.pendingChanges(for: folder)
        let branch = try await repositoryAdapter.currentBranch(for: folder)

        let status: SyncStatus
        if !changes.isEmpty {
            status = SyncStatus(state: .localChanges(changes.count), branch: branch)
        } else if branch.isMain {
            try await repositoryAdapter.fetch(folder)
            let (_, behind) = try await repositoryAdapter.aheadBehind(for: folder)
            let state: SyncState = behind > 0 ? .pullNeeded : .upToDate
            status = SyncStatus(state: state, branch: branch)
        } else {
            let (ahead, _) = try await repositoryAdapter.aheadBehind(for: folder)
            let hasUpstream = try await repositoryAdapter.hasUpstream(for: folder)
            let state: SyncState
            if !hasUpstream || ahead > 0 {
                state = .pushNeeded
            } else {
                state = .readyToMerge
            }
            status = SyncStatus(state: state, branch: branch)
        }
        cacheStatus(status, for: folder)
        return status
    }

    public func pendingChanges(for folder: Folder) async throws -> [Change] {
        try await repositoryAdapter.pendingChanges(for: folder)
    }

    public func discardChanges(in folder: Folder) async throws {
        try await repositoryAdapter.discardChanges(in: folder)
    }

    public func diff(for folder: Folder, at path: RelativePath) async throws -> FileDiff {
        try await repositoryAdapter.diff(for: folder, path: path)
    }

    public func discardChange(in folder: Folder, at path: RelativePath) async throws {
        try await repositoryAdapter.discardChange(in: folder, path: path)
    }

    public func commit(in folder: Folder, message: String) async throws {
        let branch = try await repositoryAdapter.currentBranch(for: folder)
        if branch.isMain {
            let branchName = "noteblob/\(Self.branchTimestamp())"
            try await repositoryAdapter.createBranchAndSwitch(named: branchName, in: folder)
        }
        try await repositoryAdapter.commitAll(in: folder, message: message)
    }

    public func push(_ folder: Folder) async throws {
        let branch = try await repositoryAdapter.currentBranch(for: folder)

        guard !branch.isMain else {
            throw NoteBlobError.invalidOperation(
                "Cannot push from main branch. Commit first to create a local branch.")
        }

        let (ahead, _) = try await repositoryAdapter.aheadBehind(for: folder)
        guard ahead > 0 else {
            try await cleanUpBranch(branch.name, in: folder)
            return
        }

        try await repositoryAdapter.push(folder)
    }

    public func commitLog(for folder: Folder, limit: Int = 20, downToRef: String? = "main")
        async throws -> [CommitInfo]
    {
        try await repositoryAdapter.log(
            for: folder, options: LogOptions(limit: limit, downToRef: downToRef))
    }

    public func unpushedCommitCount(for folder: Folder) async throws -> Int {
        let (ahead, _) = try await repositoryAdapter.aheadBehind(for: folder)
        return ahead
    }

    public func pull(_ folder: Folder) async throws {
        try await repositoryAdapter.pull(folder)
        eventPublisher.publish(.didPull(folder))
    }

    public func merge(_ folder: Folder) async throws {
        guard let repository = folder.repository else {
            throw NoteBlobError.invalidOperation("Cannot merge a local folder.")
        }
        let branch = try await repositoryAdapter.currentBranch(for: folder)

        guard !branch.isMain else {
            throw NoteBlobError.invalidOperation("Cannot merge from main branch.")
        }

        let credentials = try credentials()

        let existingPRs = try await pullRequestAdapter.listPullRequests(
            ListPullRequestsRequest(
                owner: repository.owner,
                repo: repository.name,
                head: branch.name,
                credentials: credentials
            )
        )

        let pr: PullRequest
        if let existingPR = existingPRs.first {
            pr = existingPR
        } else {
            pr = try await pullRequestAdapter.createPullRequest(
                CreatePullRequestRequest(
                    owner: repository.owner,
                    repo: repository.name,
                    head: branch.name,
                    base: "main",
                    title: "NoteBlob: \(branch.name)",
                    credentials: credentials
                )
            )
        }

        do {
            try await pullRequestAdapter.mergePullRequest(
                MergePullRequestRequest(
                    owner: repository.owner,
                    repo: repository.name,
                    number: pr.number,
                    credentials: credentials
                )
            )
        } catch {
            throw NoteBlobError.mergeConflict(prURL: pr.htmlURL)
        }

        let branchName = branch.name
        try await repositoryAdapter.switchBranch(to: "main", in: folder)
        try await repositoryAdapter.pull(folder)
        try await repositoryAdapter.deleteBranch(named: branchName, in: folder)
        eventPublisher.publish(.didMerge(folder))
    }

    // MARK: - Combined Operations

    public func commitAndPush(in folder: Folder, message: String) async throws {
        try await commit(in: folder, message: message)
        try await push(folder)
    }

    public func commitPushAndMerge(in folder: Folder, message: String) async throws {
        try await commit(in: folder, message: message)
        try await push(folder)
        try await merge(folder)
    }

    public func pushAndMerge(_ folder: Folder) async throws {
        try await push(folder)
        try await merge(folder)
    }

    // MARK: - Private

    private func cacheStatus(_ status: SyncStatus, for folder: Folder) {
        cachedStatus.withLock { $0[folder.id] = status }
    }

    private func cleanUpBranch(_ branchName: String, in folder: Folder) async throws {
        try await repositoryAdapter.switchBranch(to: "main", in: folder)
        try await repositoryAdapter.deleteBranch(named: branchName, in: folder)
    }

    private func credentials() throws -> Credentials {
        guard let credentials = try userRepository.loadCredentials() else {
            throw NoteBlobError.notAuthenticated
        }
        return credentials
    }

    static func branchTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
