import Foundation

final class GitHubAPIAdapter: RepositoryAdapter, @unchecked Sendable {

    private let gitClient: GitClient
    private let urlProvider: RepositoryURLProvider
    private let localPathProvider: FolderLocalPathProvider

    init(
        gitClient: GitClient,
        urlProvider: RepositoryURLProvider = GitHubRepositoryURLProvider(),
        localPathProvider: FolderLocalPathProvider
    ) {
        self.gitClient = gitClient
        self.urlProvider = urlProvider
        self.localPathProvider = localPathProvider
    }

    func cloneRepository(_ folder: Folder, credentials: Credentials) async throws {
        let remoteURL = urlProvider.remoteURL(for: folder, credentials: credentials)
        let localPath = localPathProvider.localPath(for: folder)
        try await mapError {
            try await gitClient.clone(remoteURL: remoteURL, to: localPath)
        }
    }

    func pull(_ folder: Folder) async throws {
        try await mapError {
            try await gitClient.pull(at: localPathProvider.localPath(for: folder))
        }
    }

    func push(_ folder: Folder) async throws {
        try await mapError {
            try await gitClient.push(at: localPathProvider.localPath(for: folder))
        }
    }

    func pendingChanges(for folder: Folder) async throws -> [Change] {
        try await mapError {
            try await gitClient.pendingChanges(at: localPathProvider.localPath(for: folder))
        }
    }

    func commitAll(in folder: Folder, message: String) async throws {
        try await mapError {
            try await gitClient.commitAll(
                at: localPathProvider.localPath(for: folder), message: message)
        }
    }

    func currentBranch(for folder: Folder) async throws -> BranchInfo {
        try await mapError {
            try await gitClient.currentBranch(at: localPathProvider.localPath(for: folder))
        }
    }

    func createBranchAndSwitch(named name: String, in folder: Folder) async throws {
        try await mapError {
            try await gitClient.createBranch(
                named: name, at: localPathProvider.localPath(for: folder))
        }
    }

    func switchBranch(to name: String, in folder: Folder) async throws {
        try await mapError {
            try await gitClient.switchBranch(to: name, at: localPathProvider.localPath(for: folder))
        }
    }

    func deleteBranch(named name: String, in folder: Folder) async throws {
        try await mapError {
            try await gitClient.deleteBranch(
                named: name, at: localPathProvider.localPath(for: folder))
        }
    }

    func fetch(_ folder: Folder) async throws {
        try await mapError {
            try await gitClient.fetch(at: localPathProvider.localPath(for: folder))
        }
    }

    func aheadBehind(for folder: Folder) async throws -> (ahead: Int, behind: Int) {
        try await mapError {
            try await gitClient.aheadBehind(at: localPathProvider.localPath(for: folder))
        }
    }

    func hasUpstream(for folder: Folder) async throws -> Bool {
        try await mapError {
            try await gitClient.hasUpstream(at: localPathProvider.localPath(for: folder))
        }
    }

    func discardChanges(in folder: Folder) async throws {
        try await mapError {
            try await gitClient.discardChanges(at: localPathProvider.localPath(for: folder))
        }
    }

    func discardChange(in folder: Folder, path: RelativePath) async throws {
        try await mapError {
            try await gitClient.discardChange(
                at: localPathProvider.localPath(for: folder), path: path.value)
        }
    }

    func diff(for folder: Folder, path: RelativePath) async throws -> FileDiff {
        try await mapError {
            try await gitClient.diff(at: localPathProvider.localPath(for: folder), path: path.value)
        }
    }

    func log(for folder: Folder, options: LogOptions) async throws -> [CommitInfo] {
        try await mapError {
            try await gitClient.log(at: localPathProvider.localPath(for: folder), options: options)
        }
    }

    // MARK: - Private

    private func mapError<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as GitClientError {
            throw mapGitClientError(error)
        }
    }

    private func mapGitClientError(_ error: GitClientError) -> NoteBlobError {
        switch error {
        case .conflict:
            .conflict
        case .commandFailed(_, let output):
            .syncFailed(output)
        case .apiError(_, let message):
            .syncFailed(message)
        case .missingMetadata:
            .syncFailed(error.localizedDescription)
        }
    }
}
