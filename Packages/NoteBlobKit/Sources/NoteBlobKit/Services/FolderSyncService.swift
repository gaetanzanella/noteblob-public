import Foundation
import Synchronization

public final class FolderSyncService: Sendable {

    private let userRepository: UserRepository
    private let folderRepository: FolderRepository
    private let repositoryAdapter: RepositoryAdapter
    private let pullRequestAdapter: PullRequestAdapter
    private let searchRepositoryAdapter: SearchRepositoryAdapter
    private let eventPublisher: SyncEventPublisher

    private let cachedStatus = Mutex<[String: SyncStatus]>([:])
    private let inflightStatus = Mutex<[String: Task<SyncStatus, any Error>]>([:])

    init(
        userRepository: UserRepository,
        folderRepository: FolderRepository,
        repositoryAdapter: RepositoryAdapter,
        pullRequestAdapter: PullRequestAdapter,
        searchRepositoryAdapter: SearchRepositoryAdapter,
        eventPublisher: SyncEventPublisher
    ) {
        self.userRepository = userRepository
        self.folderRepository = folderRepository
        self.repositoryAdapter = repositoryAdapter
        self.pullRequestAdapter = pullRequestAdapter
        self.searchRepositoryAdapter = searchRepositoryAdapter
        self.eventPublisher = eventPublisher
    }

    public func lastStatus(for folder: Folder) -> SyncStatus? {
        cachedStatus.withLock { $0[folder.id] }
    }

    // MARK: - Folder management

    public func syncedFolders() throws -> [Folder] {
        try folderRepository.list()
    }

    public func searchRepositories(query: String) async throws -> [Repository] {
        let credentials = try credentials()
        return try await searchRepositoryAdapter.searchRepositories(query: query, credentials: credentials)
    }

    public func listBranches(for repository: Repository) async throws -> [String] {
        let credentials = try credentials()
        return try await searchRepositoryAdapter.listBranches(for: repository, credentials: credentials)
    }

    public func add(_ folder: Folder) async throws {
        if folder.isGitBacked {
            let credentials = try credentials()
            try await repositoryAdapter.cloneRepository(folder, credentials: credentials)
            try folderRepository.add(folder)
        } else {
            try folderRepository.add(folder)
        }
    }

    public func createRepository(name: String, description: String?, isPrivate: Bool) async throws -> Folder {
        let credentials = try credentials()
        let (repository, defaultBranch) = try await searchRepositoryAdapter.createRepository(
            name: name,
            description: description,
            isPrivate: isPrivate,
            credentials: credentials
        )
        let folder = Folder(repository: repository, defaultBranch: defaultBranch)
        try await repositoryAdapter.cloneRepository(folder, credentials: credentials)
        try folderRepository.add(folder)
        return folder
    }

    public func remove(_ folder: Folder) throws {
        try folderRepository.remove(folder)
        eventPublisher.publish(.didDelete(folder))
    }

    // MARK: - Sync

    public func status(for folder: Folder) async throws -> SyncStatus {
        if let inflight = inflightStatus.withLock({ $0[folder.id] }) {
            return try await inflight.value
        }

        let task = Task { [self] in
            try await _status(for: folder)
        }
        inflightStatus.withLock { $0[folder.id] = task }

        do {
            let result = try await task.value
            _ = inflightStatus.withLock { $0.removeValue(forKey: folder.id) }
            return result
        } catch {
            _ = inflightStatus.withLock { $0.removeValue(forKey: folder.id) }
            throw error
        }
    }

    private func _status(for folder: Folder) async throws -> SyncStatus {
        guard let defaultBranch = folder.defaultBranch else {
            return SyncStatus(state: .notBacked, branch: BranchInfo(name: "local"))
        }

        let changes = try await repositoryAdapter.pendingChanges(for: folder)
        let branch = try await repositoryAdapter.currentBranch(for: folder)

        let status: SyncStatus
        if !changes.isEmpty {
            status = SyncStatus(state: .localChanges(changes.count), branch: branch)
        } else if folder.isDefault(branch) {
            try await repositoryAdapter.fetch(folder)
            let (_, behind) = try await repositoryAdapter.aheadBehind(for: folder, defaultBranch: defaultBranch)
            let state: SyncState = behind > 0 ? .pullNeeded : .upToDate
            status = SyncStatus(state: state, branch: branch)
        } else {
            let (ahead, _) = try await repositoryAdapter.aheadBehind(for: folder, defaultBranch: defaultBranch)
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
        invalidateStatus(for: folder)
        eventPublisher.publish(.didDiscard(folder))
    }

    public func diff(for folder: Folder, at path: RelativePath) async throws -> FileDiff {
        try await repositoryAdapter.diff(for: folder, path: path)
    }

    public func discardChange(in folder: Folder, at path: RelativePath) async throws {
        try await repositoryAdapter.discardChange(in: folder, path: path)
        invalidateStatus(for: folder)
        eventPublisher.publish(.didDiscard(folder))
    }

    public func commit(in folder: Folder, message: String) async throws {
        let branch = try await repositoryAdapter.currentBranch(for: folder)
        if folder.isDefault(branch) {
            let branchName = "noteblob/\(Self.branchTimestamp())"
            try await repositoryAdapter.createBranchAndSwitch(named: branchName, in: folder)
        }
        try await repositoryAdapter.commitAll(in: folder, message: message)
        invalidateStatus(for: folder)
    }

    public func push(_ folder: Folder) async throws {
        guard let defaultBranch = folder.defaultBranch else {
            throw NoteBlobError.invalidOperation("Cannot push a local folder.")
        }
        let branch = try await repositoryAdapter.currentBranch(for: folder)

        guard !folder.isDefault(branch) else {
            throw NoteBlobError.invalidOperation(
                "Cannot push from main branch. Commit first to create a local branch.")
        }

        let (ahead, _) = try await repositoryAdapter.aheadBehind(for: folder, defaultBranch: defaultBranch)
        guard ahead > 0 else {
            try await cleanUpBranch(branch.name, in: folder, defaultBranch: defaultBranch)
            invalidateStatus(for: folder)
            return
        }

        try await repositoryAdapter.push(folder)
        invalidateStatus(for: folder)
    }

    public func commitLog(for folder: Folder, limit: Int = 20, downToRef: String? = nil)
        async throws -> [CommitInfo]
    {
        try await repositoryAdapter.log(
            for: folder, options: LogOptions(limit: limit, downToRef: downToRef ?? folder.defaultBranch))
    }

    public func unpushedCommitCount(for folder: Folder) async throws -> Int {
        guard let defaultBranch = folder.defaultBranch else { return 0 }
        let (ahead, _) = try await repositoryAdapter.aheadBehind(for: folder, defaultBranch: defaultBranch)
        return ahead
    }

    public func pull(_ folder: Folder) async throws {
        try await repositoryAdapter.pull(folder)
        invalidateStatus(for: folder)
        eventPublisher.publish(.didPull(folder))
    }

    public func merge(_ folder: Folder) async throws {
        guard let repository = folder.repository, let defaultBranch = folder.defaultBranch else {
            throw NoteBlobError.invalidOperation("Cannot merge a local folder.")
        }
        let branch = try await repositoryAdapter.currentBranch(for: folder)

        guard !folder.isDefault(branch) else {
            throw NoteBlobError.invalidOperation("Cannot merge from main branch.")
        }

        let credentials = try credentials()

        let openPRs = try await pullRequestAdapter.listPullRequests(
            ListPullRequestsRequest(
                owner: repository.owner,
                repo: repository.name,
                head: branch.name,
                credentials: credentials
            )
        )

        let pr: PullRequest?
        if let openPR = openPRs.first {
            pr = openPR
        } else {
            do {
                pr = try await pullRequestAdapter.createPullRequest(
                    CreatePullRequestRequest(
                        owner: repository.owner,
                        repo: repository.name,
                        head: branch.name,
                        base: defaultBranch,
                        title: "NoteBlob: \(branch.name)",
                        credentials: credentials
                    )
                )
            } catch GitClientError.noDiff {
                // Branch already fully merged — skip to cleanup
                pr = nil
            }
        }

        if let pr {
            do {
                try await pullRequestAdapter.mergePullRequest(
                    MergePullRequestRequest(
                        owner: repository.owner,
                        repo: repository.name,
                        number: pr.number,
                        credentials: credentials
                    )
                )
            } catch GitClientError.conflict {
                throw NoteBlobError.mergeConflict(prURL: pr.htmlURL)
            }
        }

        let branchName = branch.name

        try? await pullRequestAdapter.deleteRemoteBranch(
            DeleteBranchRequest(
                owner: repository.owner,
                repo: repository.name,
                branch: branchName,
                credentials: credentials
            )
        )

        try await repositoryAdapter.switchBranch(to: defaultBranch, in: folder)
        try await repositoryAdapter.pull(folder)
        try await repositoryAdapter.deleteBranch(named: branchName, in: folder)
        invalidateStatus(for: folder)
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

    /// Drop the cached status AND cancel any in-flight status computation for
    /// the folder. Call this after any git-mutating operation so the next
    /// `status(for:)` recomputes from scratch — otherwise a refresh request
    /// that lands during a slow, pre-mutation fetch deduplicates into the
    /// stale in-flight task and returns the pre-mutation state.
    private func invalidateStatus(for folder: Folder) {
        _ = cachedStatus.withLock { $0.removeValue(forKey: folder.id) }
        inflightStatus.withLock {
            $0[folder.id]?.cancel()
            $0.removeValue(forKey: folder.id)
        }
    }

    private func cleanUpBranch(_ branchName: String, in folder: Folder, defaultBranch: String) async throws {
        try await repositoryAdapter.switchBranch(to: defaultBranch, in: folder)
        try await repositoryAdapter.deleteBranch(named: branchName, in: folder)
    }

    private func credentials() throws -> Credentials {
        let credentials: Credentials?
        do {
            credentials = try userRepository.loadCredentials()
        } catch {
            throw NoteBlobError.notAuthenticated
        }
        guard let credentials else {
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
