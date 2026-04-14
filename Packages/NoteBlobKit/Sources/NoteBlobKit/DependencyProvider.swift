import Foundation

public final class DependencyProvider: Sendable {

    private let localPathProvider: FolderLocalPathProvider

    private let userRepository: UserRepository
    private let folderRepository: FolderRepository
    private let repositoryAdapter: RepositoryAdapter
    private let pullRequestAdapter: PullRequestAdapter
    private let fileRepository: FileRepository
    private let folderSyncService: FolderSyncService
    private let llmRepository: LLMRepository
    private let settingsRepository: SettingsRepository
    private let usageRepository: UsageRepository
    private let syncEventPublisher: SyncEventPublisher
    private let noteEventPublisher: NoteEventPublisher

    public convenience init(
        localPathProvider: FolderLocalPathProvider,
        credentialsProvider: CredentialsProvider? = nil,
        repositoryURLProvider: RepositoryURLProvider? = nil
    ) {
        self.init(
            localPathProvider: localPathProvider,
            credentialsProvider: credentialsProvider,
            repositoryURLProvider: repositoryURLProvider,
            pullRequestAdapter: nil,
            settingsRepository: nil
        )
    }

    init(
        localPathProvider: FolderLocalPathProvider,
        credentialsProvider: CredentialsProvider? = nil,
        repositoryURLProvider: RepositoryURLProvider? = nil,
        pullRequestAdapter: PullRequestAdapter? = nil,
        settingsRepository: SettingsRepository? = nil
    ) {
        self.localPathProvider = localPathProvider

        let gitClient = SwiftGitXClient()
        self.userRepository = KeychainAuthAdapter(credentialsProvider: credentialsProvider)
        self.folderRepository = FileSystemFolderRepository(localPathProvider: localPathProvider)
        self.repositoryAdapter = GitHubAPIAdapter(
            gitClient: gitClient,
            urlProvider: repositoryURLProvider ?? GitHubRepositoryURLProvider(),
            localPathProvider: localPathProvider
        )
        self.pullRequestAdapter = pullRequestAdapter ?? GitHubPullRequestAdapter()
        self.fileRepository = LocalFileAdapter()
        self.syncEventPublisher = SyncEventPublisher()
        self.noteEventPublisher = NoteEventPublisher()
        self.folderSyncService = FolderSyncService(
            userRepository: self.userRepository,
            folderRepository: self.folderRepository,
            repositoryAdapter: self.repositoryAdapter,
            pullRequestAdapter: self.pullRequestAdapter,
            eventPublisher: self.syncEventPublisher
        )
        self.llmRepository = NativeLLMAdapter()
        self.settingsRepository = settingsRepository ?? UserDefaultsSettingsAdapter()
        self.usageRepository = UserDefaultsUsageAdapter()
    }

    public func makeLocalPathProvider() -> FolderLocalPathProvider {
        localPathProvider
    }

    public func makeAuthService() -> AuthService {
        AuthService(userRepository: userRepository)
    }

    public func makeNoteService(for folder: Folder) -> NoteService {
        let localPath = localPathProvider.localPath(for: folder)
        return NoteService(
            folder: folder,
            fileRepository: fileRepository,
            localPathProvider: localPathProvider,
            repositoryAdapter: repositoryAdapter,
            contentSearchRepository: GrepContentSearchAdapter(rootURL: localPath),
            noteEventPublisher: noteEventPublisher,
            usageRepository: usageRepository
        )
    }

    public func makeFolderSyncService() -> FolderSyncService {
        folderSyncService
    }

    public func makeAIAssistantService() -> AIAssistantService {
        AIAssistantService(llmRepository: llmRepository)
    }

    public func makeSettingsService() -> SettingsService {
        SettingsService(settingsRepository: settingsRepository)
    }

    public func makeSyncEventPublisher() -> SyncEventPublisher {
        syncEventPublisher
    }

    public func makeNoteEventPublisher() -> NoteEventPublisher {
        noteEventPublisher
    }
}
