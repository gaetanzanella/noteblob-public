import Foundation
import NoteBlobKit

// MARK: - Navigation

public enum FolderListViewAction {
    case load
    case select(String?)
    case delete(String)
    case dismissAlert
    case addFolder
    case account
}

public struct AddFolderNavigationPayload {
    public let onFoldersChanged: @MainActor () -> Void
}

public enum FolderListRedirection {
    case folder(FolderNavigationPayload?, isRestoration: Bool = false)
    case addFolder(AddFolderNavigationPayload)
    case account
}

public struct FolderNavigationPayload: Hashable, Codable {
    public let folder: Folder
    public let path: RelativePath

    public init(folder: Folder, path: RelativePath = .root) {
        self.folder = folder
        self.path = path
    }
}

// MARK: - ViewModel

struct FolderListViewModel {

    struct Row: Identifiable {
        let id: String
        let name: String
    }

    let rows: [Row]
    let subtitle: String
    let errorMessage: String?
    let alert: AlertViewModel?
}

// MARK: - State

private struct FolderListState {
    var folders: [Folder] = []
    var errorMessage: String?
    var alert: AlertViewModel?
}

// MARK: - Presenter

@Observable
@MainActor
public final class FolderListPresenter {

    private var state = FolderListState()
    private let folderSyncService: FolderSyncService
    private let onRedirection: (FolderListRedirection) -> Void
    private var initialFolderID: String?

    public init(
        folderSyncService: FolderSyncService,
        initialFolderID: String? = nil,
        onRedirection: @escaping (FolderListRedirection) -> Void
    ) {
        self.folderSyncService = folderSyncService
        self.initialFolderID = initialFolderID
        self.onRedirection = onRedirection
    }

    func viewModel() -> FolderListViewModel {
        let count = state.folders.count
        return FolderListViewModel(
            rows: state.folders.map { FolderListViewModel.Row(id: $0.id, name: $0.name) },
            subtitle: .localized("folder_list.subtitle \(count)"),
            errorMessage: state.errorMessage,
            alert: state.alert
        )
    }

    public func on(_ action: FolderListViewAction) {
        switch action {
        case .load:
            loadFolders()
        case .select(let id):
            if let folder = state.folders.first(where: { $0.id == id }) {
                onRedirection(.folder(FolderNavigationPayload(folder: folder)))
            } else {
                onRedirection(.folder(nil))
            }
        case .delete(let id):
            guard let folder = state.folders.first(where: { $0.id == id }) else { return }
            confirmDelete(folder)
        case .dismissAlert:
            state.alert = nil
        case .addFolder:
            onRedirection(.addFolder(AddFolderNavigationPayload(onFoldersChanged: { [weak self] in
                self?.loadFolders()
            })))
        case .account:
            onRedirection(.account)
        }
    }

    private func loadFolders() {
        do {
            state.folders = try folderSyncService.syncedFolders()
            if let id = initialFolderID,
               let folder = state.folders.first(where: { $0.id == id }) {
                initialFolderID = nil
                onRedirection(.folder(FolderNavigationPayload(folder: folder), isRestoration: true))
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func confirmDelete(_ folder: Folder) {
        state.alert = Alerts.confirmDeleteFolder(name: folder.name) { [weak self] in
            self?.remove(folder)
        }
    }

    private func remove(_ folder: Folder) {
        do {
            try folderSyncService.remove(folder)
            loadFolders()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

}
