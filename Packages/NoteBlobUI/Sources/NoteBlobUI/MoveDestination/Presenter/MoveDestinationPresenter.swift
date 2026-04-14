import Foundation
import NoteBlobKit

// MARK: - Action

public enum MoveDestinationViewAction {
    case load
    case select(RelativePath)
    case confirm
}

// MARK: - Redirection

public enum MoveDestinationRedirection {
    case didMove
}

// MARK: - ViewModel

struct MoveDestinationViewModel {

    struct Row: Identifiable {
        let id: String
        let path: RelativePath
        let name: String
        let depth: Int
        let isDisabled: Bool
        let children: [Row]?
    }

    let title: String
    let rows: [Row]
    let isRootDisabled: Bool
    let selectedPath: RelativePath?
    let canConfirm: Bool
    let alert: AlertViewModel?
}

// MARK: - State

private struct MoveDestinationState {
    let folder: Folder
    let currentPath: RelativePath
    let itemPaths: [RelativePath]
    let excludedPaths: Set<String>
    var tree: [FolderTreeNode] = []
    var selectedPath: RelativePath?
    var alert: AlertViewModel?
}

// MARK: - Presenter

@Observable
@MainActor
public final class MoveDestinationPresenter {

    private var state: MoveDestinationState
    private let noteService: NoteService
    private let onRedirection: (MoveDestinationRedirection) -> Void

    public init(
        payload: MoveNavigationPayload,
        noteService: NoteService,
        onRedirection: @escaping (MoveDestinationRedirection) -> Void
    ) {
        self.state = MoveDestinationState(
            folder: payload.folder,
            currentPath: payload.currentPath,
            itemPaths: payload.itemPaths,
            excludedPaths: Set(payload.itemPaths.map(\.value))
        )
        self.noteService = noteService
        self.onRedirection = onRedirection
    }

    func viewModel() -> MoveDestinationViewModel {
        MoveDestinationViewModel(
            title: state.folder.name,
            rows: mapNodes(state.tree, depth: 0),
            isRootDisabled: state.currentPath == .root,
            selectedPath: state.selectedPath,
            canConfirm: state.selectedPath != nil,
            alert: state.alert
        )
    }

    public func on(_ action: MoveDestinationViewAction) {
        switch action {
        case .load:
            load()
        case .select(let path):
            guard path != state.currentPath else { return }
            guard !state.excludedPaths.contains(path.value) else { return }
            state.selectedPath = path
        case .confirm:
            moveItems()
        }
    }

    // MARK: - Private

    private func load() {
        do {
            state.tree = try noteService.listFolderTree(in: state.folder, at: .root)
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func moveItems() {
        guard let destination = state.selectedPath else { return }
        do {
            for path in state.itemPaths {
                try noteService.moveItem(in: state.folder, at: path, to: destination)
            }
            onRedirection(.didMove)
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func mapNodes(_ nodes: [FolderTreeNode], depth: Int) -> [MoveDestinationViewModel.Row] {
        nodes
            .filter { !state.excludedPaths.contains($0.path.value) }
            .map { node in
                MoveDestinationViewModel.Row(
                    id: node.path.value,
                    path: node.path,
                    name: node.name,
                    depth: depth,
                    isDisabled: node.path == state.currentPath,
                    children: node.children.map { mapNodes($0, depth: depth + 1) }
                )
            }
    }
}
