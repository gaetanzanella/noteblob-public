import Foundation
import NoteBlobKit
import MCPServerKit

@MainActor
public final class PresenterFactory {

    private let dependencyProvider: DependencyProvider
    private let mcpServer: NoteBlobMCPServer

    public init(dependencyProvider: DependencyProvider) {
        self.dependencyProvider = dependencyProvider
        self.mcpServer = NoteBlobMCPServer(
            adapter: NoteBlobRepositoryAdapter(dependencyProvider: dependencyProvider)
        )
    }

    public func makeRootPresenter() -> RootPresenter {
        RootPresenter(
            settingsService: dependencyProvider.makeSettingsService(),
            mcpServerController: mcpServer
        )
    }

    public func makeAuthPresenter(
        payload: AuthenticateNavigationPayload,
        onRedirection: @escaping (AuthRedirection) -> Void
    ) -> AuthPresenter {
        AuthPresenter(
            payload: payload,
            authService: dependencyProvider.makeAuthService(),
            onRedirection: onRedirection
        )
    }

    public func makeFolderListPresenter(
        initialFolderID: String? = nil,
        onRedirection: @escaping (FolderListRedirection) -> Void
    ) -> FolderListPresenter {
        FolderListPresenter(
            folderSyncService: dependencyProvider.makeFolderSyncService(),
            initialFolderID: initialFolderID,
            onRedirection: onRedirection
        )
    }

    public func makeAccountPresenter(
        onRedirection: @escaping (AccountRedirection) -> Void
    ) -> AccountPresenter {
        AccountPresenter(
            authService: dependencyProvider.makeAuthService(),
            settingsService: dependencyProvider.makeSettingsService(),
            mcpServerController: mcpServer,
            onRedirection: onRedirection
        )
    }

    public func makeAddFolderMenuPresenter(
        onRedirection: @escaping (AddFolderMenuRedirection) -> Void
    ) -> AddFolderMenuPresenter {
        AddFolderMenuPresenter(
            authService: dependencyProvider.makeAuthService(),
            onRedirection: onRedirection
        )
    }

    public func makeAddFolderPresenter(
        mode: AddFolderMode,
        onRedirection: @escaping (AddFolderRedirection) -> Void
    ) -> AddFolderPresenter {
        AddFolderPresenter(
            mode: mode,
            folderSyncService: dependencyProvider.makeFolderSyncService(),
            onRedirection: onRedirection
        )
    }

    public func makeFolderPresenter(
        payload: FolderNavigationPayload,
        selection: @escaping () -> String? = { nil },
        onRedirection: @escaping (FolderRedirection) -> Void,
        currentPath: @escaping () -> RelativePath?
    ) -> FolderPresenter {
        FolderPresenter(
            payload: payload,
            noteService: dependencyProvider.makeNoteService(for: payload.folder),
            syncEventPublisher: dependencyProvider.makeSyncEventPublisher(),
            selection: selection,
            onRedirection: onRedirection,
            currentPath: currentPath
        )
    }

    public func makeNotePresenter(
        payload: NoteNavigationPayload,
        onRedirection: @escaping (NoteRedirection) -> Void
    ) -> NotePresenter {
        NotePresenter(
            payload: payload,
            noteService: dependencyProvider.makeNoteService(for: payload.folder),
            syncEventPublisher: dependencyProvider.makeSyncEventPublisher(),
            noteEventPublisher: dependencyProvider.makeNoteEventPublisher(),
            onRedirection: onRedirection
        )
    }

    public func makeSyncPresenter(
        folder: Folder,
        onRedirection: @escaping (SyncRedirection) -> Void
    ) -> SyncPresenter {
        SyncPresenter(
            folder: folder,
            folderSyncService: dependencyProvider.makeFolderSyncService(),
            onRedirection: onRedirection
        )
    }

    public func makeSearchPresenter(
        folder: Folder,
        onRedirection: @escaping (SearchRedirection) -> Void
    ) -> SearchPresenter {
        SearchPresenter(
            folder: folder,
            noteService: dependencyProvider.makeNoteService(for: folder),
            onRedirection: onRedirection
        )
    }

    public func makeMoveDestinationPresenter(
        payload: MoveNavigationPayload,
        onRedirection: @escaping (MoveDestinationRedirection) -> Void
    ) -> MoveDestinationPresenter {
        MoveDestinationPresenter(
            payload: payload,
            noteService: dependencyProvider.makeNoteService(for: payload.folder),
            onRedirection: onRedirection
        )
    }

    public func makeDiffPresenter(
        payload: DiffNavigationPayload
    ) -> DiffPresenter {
        DiffPresenter(
            payload: payload,
            folderSyncService: dependencyProvider.makeFolderSyncService()
        )
    }

    public func makeCommitPresenter(
        payload: CommitNavigationPayload,
        onRedirection: @escaping (CommitRedirection) -> Void
    ) -> CommitPresenter {
        CommitPresenter(
            payload: payload,
            folderSyncService: dependencyProvider.makeFolderSyncService(),
            aiAssistantService: dependencyProvider.makeAIAssistantService(),
            onRedirection: onRedirection
        )
    }
}
