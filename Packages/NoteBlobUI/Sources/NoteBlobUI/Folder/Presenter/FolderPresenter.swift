import Foundation
import NoteBlobKit

// MARK: - Navigation

public enum FolderViewAction {
    case load
    case select(String?)
    case selectMultiple(Set<String>)
    case doubleTap(String)
    case delete(String)
    case rename(id: String, newName: String)
    case createNote(name: String)
    case createFolder(name: String)
    case startEditing
    case stopEditing
    case startMove
    case startMoveItem(id: String)
    case didMove
    case deleteSelected
    case moveItemsToFolder(paths: [RelativePath], destinationFolder: Folder, destinationPath: RelativePath)
    case copyItemsToFolder(paths: [RelativePath], destinationFolder: Folder, destinationPath: RelativePath)
    case selectRecentNote(NoteNavigationPayload)
    case dismissError
}

public struct MoveNavigationPayload {
    public let folder: Folder
    public let currentPath: RelativePath
    public let itemPaths: [RelativePath]
    public let onDidMove: @MainActor () -> Void
}

public enum FolderRedirection {
    case folder(FolderNavigationPayload)
    case note(NoteNavigationPayload)
    case deeplink(NoteNavigationPayload)
    case doubleTap(NoteNavigationPayload)
    case quickLook(URL)
    case newNote
    case deselect
    case movePicker(MoveNavigationPayload)
    case folderNotFound
    case resetContent
}

public struct NoteNavigationPayload: Hashable, Codable {
    public let folder: Folder
    public let path: RelativePath

    public var id: String {
        path.value
    }

    public init(folder: Folder, path: RelativePath) {
        self.folder = folder
        self.path = path
    }
}

public struct CommitNavigationPayload {
    public let folder: Folder

    public init(folder: Folder) {
        self.folder = folder
    }
}

// MARK: - ViewModel

struct FolderViewModel {

    struct Row: Identifiable {
        let id: String
        let name: String
        let systemImage: String
        let isFolder: Bool

        var noteItem: NoteItem {
            let path = RelativePath(id)
            if isFolder {
                return .folder(NoteFolder(name: name, path: path))
            } else {
                return .file(NoteFile(name: name, path: path))
            }
        }
    }

    struct RecentNote: Identifiable {
        let payload: NoteNavigationPayload
        let file: NoteFile

        var id: String { payload.id }
    }

    let title: String
    let subtitle: String
    let rows: [Row]
    let recentNotes: [RecentNote]
    let isEditing: Bool
    let selectedIDs: Set<String>
    let alert: AlertViewModel?
}

// MARK: - State

private struct FolderState {
    let payload: FolderNavigationPayload
    var items: [NoteItem] = []
    var alert: AlertViewModel?
}

// MARK: - Presenter

@Observable
@MainActor
public final class FolderPresenter {

    private var state: FolderState
    private let noteService: NoteService
    private let onRedirection: (FolderRedirection) -> Void
    private let externalSelection: () -> String?
    private let currentPath: () -> RelativePath?
    private var isEditing = false
    private var selectedIDs: Set<String> = []
    private var syncSubscription: SyncEventPublisher.Subscription?

    public init(
        payload: FolderNavigationPayload,
        noteService: NoteService,
        syncEventPublisher: SyncEventPublisher,
        selection: @escaping () -> String? = { nil },
        onRedirection: @escaping (FolderRedirection) -> Void,
        currentPath: @escaping () -> RelativePath?
    ) {
        self.state = FolderState(payload: payload)
        self.noteService = noteService
        self.externalSelection = selection
        self.onRedirection = onRedirection
        self.currentPath = currentPath
        subscribeToSyncEvents(syncEventPublisher, folder: payload.folder)
    }

    var folder: Folder {
        state.payload.folder
    }

    var folderPath: RelativePath {
        state.payload.path
    }

    func viewModel() -> FolderViewModel {
        let folderCount = state.items.filter { $0.isFolder }.count
        let noteCount = state.items.filter { !$0.isFolder }.count
        let subtitleParts: [String] = [
            .localized("folder.subtitle.notes \(noteCount)"),
            .localized("folder.subtitle.folders \(folderCount)"),
        ].filter { !$0.isEmpty }
        let recentNotes = noteService.recentNotes(limit: 5).map { file in
            FolderViewModel.RecentNote(
                payload: NoteNavigationPayload(
                    folder: state.payload.folder,
                    path: file.path
                ),
                file: file
            )
        }
        return FolderViewModel(
            title: state.payload.path == .root
                ? state.payload.folder.name
                : state.payload.path.lastComponent,
            subtitle: subtitleParts.joined(separator: ", "),
            rows: state.items.map { item in
                return FolderViewModel.Row(
                    id: item.path.value,
                    name: item.name,
                    systemImage: item.isFolder ? "folder" : "doc.text",
                    isFolder: item.isFolder
                )
            },
            recentNotes: recentNotes,
            isEditing: isEditing,
            selectedIDs: selectedIDs,
            alert: state.alert
        )
    }

    public func on(_ action: FolderViewAction) {
        switch action {
        case .load:
            loadItems()
        case .doubleTap(let id):
            guard let item = state.items.first(where: { $0.path.value == id }),
                  case .file(let file) = item, file.type == .markdown else { return }
            onRedirection(.doubleTap(
                NoteNavigationPayload(folder: state.payload.folder, path: item.path)
            ))
        case .select(let id):
            selectedIDs = id.map { Set([$0]) } ?? []
            guard let id, let item = state.items.first(where: { $0.path.value == id }) else {
                onRedirection(.deselect)
                return
            }
            switch item {
            case .folder:
                onRedirection(
                    .folder(
                        FolderNavigationPayload(
                            folder: state.payload.folder,
                            path: item.path
                        )))
            case .file(let file):
                if file.type == .markdown {
                    onRedirection(
                        .note(
                            NoteNavigationPayload(
                                folder: state.payload.folder,
                                path: item.path
                            )))
                } else {
                    onRedirection(
                        .quickLook(
                            noteService.fileURL(in: state.payload.folder, at: item.path)
                        ))
                }
            }
        case .selectMultiple(let ids):
            selectedIDs = ids
            guard !isEditing else { return }
            if ids.count == 1, let id = ids.first {
                on(.select(id))
            } else if ids.isEmpty {
                onRedirection(.deselect)
            }
        case .delete(let id):
            guard let item = state.items.first(where: { $0.path.value == id }) else { return }
            confirmDelete([item])
        case .rename(let id, let newName):
            guard let item = state.items.first(where: { $0.path.value == id }) else { return }
            renameItem(item, newName: newName)
        case .createNote(let name):
            createNote(name: name)
        case .createFolder(let name):
            createFolder(name: name)
        case .startEditing:
            isEditing = true
            selectedIDs = []
        case .stopEditing:
            isEditing = false
            selectedIDs = []
        case .startMove:
            startMoveRedirection(ids: selectedIDs)
        case .startMoveItem(let id):
            startMoveRedirection(ids: [id])
        case .didMove:
            isEditing = false
            selectedIDs = []
            loadItems()
        case .deleteSelected:
            let items = selectedIDs.compactMap { id in
                state.items.first(where: { $0.path.value == id })
            }
            confirmDelete(items)
        case .moveItemsToFolder(let paths, let destinationFolder, let destinationPath):
            do {
                try noteService.moveItems(in: destinationFolder, paths: paths, to: destinationPath)
                loadItems()
            } catch {
                state.alert = .error(error.localizedDescription)
            }
        case .copyItemsToFolder(let paths, let destinationFolder, let destinationPath):
            do {
                try noteService.copyItems(in: destinationFolder, paths: paths, to: destinationPath)
                loadItems()
            } catch {
                state.alert = .error(error.localizedDescription)
            }
        case .selectRecentNote(let payload):
            onRedirection(.deeplink(payload))
        case .dismissError:
            state.alert = nil
        }
    }

    private func loadItems() {
        do {
            state.items = try noteService.listItems(
                in: state.payload.folder, at: state.payload.path)
            if selectedIDs.isEmpty, let s = externalSelection() {
                selectedIDs = [s]
            }
        } catch is FileRepositoryError {
            onRedirection(.folderNotFound)
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func createNote(name: String) {
        do {
            let noteFile = try noteService.createNote(in: state.payload.folder, at: state.payload.path, name: name)
            loadItems()
            selectedIDs = [noteFile.path.value]
            onRedirection(
                .note(
                    NoteNavigationPayload(
                        folder: state.payload.folder,
                        path: noteFile.path
                    )))
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func createFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            state.alert = .error(.localized("new_folder.error.empty"))
            return
        }
        do {
            let noteFolder = try noteService.createFolder(in: state.payload.folder, at: state.payload.path, name: trimmed)
            loadItems()
            onRedirection(
                .folder(
                    FolderNavigationPayload(
                        folder: state.payload.folder,
                        path: noteFolder.path
                    )))
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func confirmDelete(_ items: [NoteItem]) {
        guard !items.isEmpty else { return }
        state.alert = Alerts.confirmDeleteItems(count: items.count) { [weak self] in
            self?.performDelete(items)
        }
    }

    private func performDelete(_ items: [NoteItem]) {
        for item in items {
            do {
                try noteService.deleteNote(in: state.payload.folder, at: item.path)
            } catch {
                state.alert = .error(error.localizedDescription)
                return
            }
        }
        isEditing = false
        selectedIDs = []
        loadItems()
    }

    private func startMoveRedirection(ids: Set<String>) {
        let paths = state.items
            .filter { ids.contains($0.path.value) }
            .map(\.path)
        guard !paths.isEmpty else { return }
        onRedirection(
            .movePicker(
                MoveNavigationPayload(
                    folder: state.payload.folder,
                    currentPath: state.payload.path,
                    itemPaths: paths,
                    onDidMove: { [weak self] in
                        self?.on(.didMove)
                    }
                )
            )
        )
    }

    private func renameItem(_ item: NoteItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            state.alert = .error(.localized("folder.rename.error.empty"))
            return
        }
        do {
            try noteService.renameNote(in: state.payload.folder, at: item.path, newName: trimmed)
            loadItems()
        } catch {
            state.alert = .error(error.localizedDescription)
        }
    }

    private func subscribeToSyncEvents(_ publisher: SyncEventPublisher, folder: Folder) {
        syncSubscription = publisher.subscribe { [weak self] event in
            guard let self else { return }
            switch event {
            case .didPull(let eventFolder),
                    .didMerge(let eventFolder),
                    .didDiscard(let eventFolder),
                    .didDelete(let eventFolder):
                guard eventFolder.id == folder.id else { return }
                Task { @MainActor in
                    self.handleSyncCompleted()
                }
            }
        }
    }

    private func handleSyncCompleted() {
        let isRoot = state.payload.path == .root

        // Non-root folder: silently return if deleted (root will handle reset)
        if !isRoot {
            let folderExists = noteService.fileExists(in: state.payload.folder, at: state.payload.path)
            guard folderExists else { return }
        }

        loadItems()

        // Root checks if current navigation path still exists
        guard isRoot, let path = currentPath() else { return }
        let pathExists = noteService.fileExists(in: state.payload.folder, at: path)
        if !pathExists {
            onRedirection(.resetContent)
        }
    }

}
