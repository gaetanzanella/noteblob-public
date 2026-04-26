import Foundation
import NoteBlobKit

// MARK: - Action

public enum MoveDestinationViewAction {
    case load
    case selectFolder(Folder)
    case select(RelativePath)
    case confirm
}

// MARK: - Redirection

public enum MoveDestinationRedirection {
    case didMove
}

// MARK: - ViewModel

struct MoveDestinationViewModel {

    struct FolderChoice: Identifiable {
        let id: String
        let folder: Folder
        let name: String
        let isSelected: Bool
    }

    struct Row: Identifiable {
        let id: String
        let path: RelativePath
        let name: String
        let depth: Int
        let isDisabled: Bool
        let children: [Row]?
    }

    let sourceFolderName: String
    let destinationFolderName: String
    let folders: [FolderChoice]
    let rows: [Row]
    let isRootDisabled: Bool
    let selectedPath: RelativePath?
    let canConfirm: Bool
    let alert: AlertViewModel?
}

// MARK: - State

private struct MoveDestinationState {
    let sourceFolder: Folder
    let sourcePath: RelativePath
    let itemPaths: [RelativePath]
    let excludedPaths: Set<String>
    var destinationFolder: Folder
    var availableFolders: [Folder] = []
    var tree: [FolderTreeNode] = []
    var selectedPath: RelativePath?
    var alert: AlertViewModel?
}

// MARK: - Presenter

@Observable
@MainActor
public final class MoveDestinationPresenter {

    private var state: MoveDestinationState
    private let folderSyncService: FolderSyncService
    private let makeNoteService: (Folder) -> NoteService
    private let onRedirection: (MoveDestinationRedirection) -> Void

    public init(
        payload: MoveNavigationPayload,
        folderSyncService: FolderSyncService,
        makeNoteService: @escaping (Folder) -> NoteService,
        onRedirection: @escaping (MoveDestinationRedirection) -> Void
    ) {
        self.state = MoveDestinationState(
            sourceFolder: payload.folder,
            sourcePath: payload.currentPath,
            itemPaths: payload.itemPaths,
            excludedPaths: Set(payload.itemPaths.map(\.value)),
            destinationFolder: payload.folder
        )
        self.folderSyncService = folderSyncService
        self.makeNoteService = makeNoteService
        self.onRedirection = onRedirection
    }

    func viewModel() -> MoveDestinationViewModel {
        let destinationFolder = state.destinationFolder
        let folders = state.availableFolders.map { folder in
            MoveDestinationViewModel.FolderChoice(
                id: folder.id,
                folder: folder,
                name: folder.name,
                isSelected: folder.id == destinationFolder.id
            )
        }
        let isSameFolder = destinationFolder.id == state.sourceFolder.id
        return MoveDestinationViewModel(
            sourceFolderName: state.sourceFolder.name,
            destinationFolderName: destinationFolder.name,
            folders: folders,
            rows: mapNodes(state.tree, depth: 0, isSameFolder: isSameFolder),
            isRootDisabled: isSameFolder && state.sourcePath == .root,
            selectedPath: state.selectedPath,
            canConfirm: state.selectedPath != nil,
            alert: state.alert
        )
    }

    public func on(_ action: MoveDestinationViewAction) {
        switch action {
        case .load:
            loadFolders()
            loadTree()
        case .selectFolder(let folder):
            guard folder.id != state.destinationFolder.id else { return }
            state.destinationFolder = folder
            state.selectedPath = nil
            loadTree()
        case .select(let path):
            if isSameFolder {
                guard path != state.sourcePath else { return }
                guard !state.excludedPaths.contains(path.value) else { return }
            }
            state.selectedPath = path
        case .confirm:
            moveItems()
        }
    }

    // MARK: - Private

    private var isSameFolder: Bool {
        state.destinationFolder.id == state.sourceFolder.id
    }

    private func loadFolders() {
        do {
            state.availableFolders = try folderSyncService.syncedFolders()
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func loadTree() {
        do {
            let service = makeNoteService(state.destinationFolder)
            state.tree = try service.listFolderTree(in: state.destinationFolder, at: .root)
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func moveItems() {
        guard let destination = state.selectedPath else { return }
        let sourceService = makeNoteService(state.sourceFolder)
        do {
            for path in state.itemPaths {
                if isSameFolder {
                    try sourceService.moveItem(in: state.sourceFolder, at: path, to: destination)
                } else {
                    try sourceService.moveItem(
                        from: state.sourceFolder, at: path,
                        to: state.destinationFolder, at: destination
                    )
                }
            }
            onRedirection(.didMove)
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func mapNodes(
        _ nodes: [FolderTreeNode], depth: Int, isSameFolder: Bool
    ) -> [MoveDestinationViewModel.Row] {
        nodes
            .filter { node in
                // Exclude self-items only when moving within the source folder.
                !isSameFolder || !state.excludedPaths.contains(node.path.value)
            }
            .map { node in
                MoveDestinationViewModel.Row(
                    id: node.path.value,
                    path: node.path,
                    name: node.name,
                    depth: depth,
                    isDisabled: isSameFolder && node.path == state.sourcePath,
                    children: node.children.map {
                        mapNodes($0, depth: depth + 1, isSameFolder: isSameFolder)
                    }
                )
            }
    }
}
