import Foundation
import NoteBlobKit

// MARK: - Navigation

public enum SyncViewAction {
    case load
    case showDetail
}

public struct SyncRedirection {
    public let payload: CommitNavigationPayload
    public let onDismiss: @MainActor () -> Void
}

// MARK: - ViewModel

struct SyncViewModel {
    let syncAction: SyncAction
    let isLoading: Bool
}

// MARK: - State

private struct SyncState {
    let folder: Folder
    var syncStatus: SyncStatus?
    var isLoading = false
    var errorMessage: String?
}

// MARK: - Presenter

@Observable
@MainActor
public final class SyncPresenter {

    private var state: SyncState
    private let folderSyncService: FolderSyncService
    private let onRedirection: (SyncRedirection) -> Void

    public init(
        folder: Folder,
        folderSyncService: FolderSyncService,
        onRedirection: @escaping (SyncRedirection) -> Void
    ) {
        self.state = SyncState(folder: folder, syncStatus: folderSyncService.lastStatus(for: folder))
        self.folderSyncService = folderSyncService
        self.onRedirection = onRedirection
    }

    func viewModel() -> SyncViewModel {
        SyncViewModel(
            syncAction: state.errorMessage.map(SyncAction.error) ?? state.syncStatus.map(mapSyncAction) ?? .none,
            isLoading: state.isLoading && state.syncStatus == nil
        )
    }

    public func on(_ action: SyncViewAction) {
        switch action {
        case .load:
            Task { await refreshStatus() }
        case .showDetail:
            onRedirection(
                SyncRedirection(
                    payload: CommitNavigationPayload(folder: state.folder),
                    onDismiss: { [weak self] in
                        guard let self else { return }
                        Task { await self.refreshStatus() }
                    }
                ))
        }
    }

    func refreshStatus() async {
        state.isLoading = true
        do {
            state.errorMessage = nil
            state.syncStatus = try await folderSyncService.status(for: state.folder)
        } catch is CancellationError {
            // A mutating op (commit/push/pull/…) invalidated the in-flight
            // status computation while we awaited it. Don't surface this as
            // an error — the caller that triggered the mutation will kick
            // off its own fresh `refreshStatus` right after.
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isLoading = false
    }

    private func mapSyncAction(_ status: SyncStatus) -> SyncAction {
        switch status.state {
        case .upToDate: .none
        case .localChanges(let count): .localChanges(count)
        case .pushNeeded: .push
        case .pullNeeded: .pull
        case .readyToMerge: .merge
        case .notBacked: .notBacked
        }
    }
}
