import Foundation
import NoteBlobKit

// MARK: - Navigation

public struct NoteLinkPickerNavigationPayload {
    public let folder: Folder
    public let excluding: RelativePath
    public let onSelected: (RelativePath, String) -> Void

    public init(
        folder: Folder,
        excluding: RelativePath,
        onSelected: @escaping (RelativePath, String) -> Void
    ) {
        self.folder = folder
        self.excluding = excluding
        self.onSelected = onSelected
    }
}

enum NoteLinkPickerViewAction {
    case search(String)
    case select(String)
}

// MARK: - ViewModel

struct NoteLinkPickerViewModel {

    struct Row: Identifiable {
        let id: String
        let name: String
        let path: RelativePath
    }

    let rows: [Row]
}

// MARK: - State

private struct NoteLinkPickerState {
    let folder: Folder
    let excluding: RelativePath
    var results: [NoteSearchResult] = []
}

// MARK: - Presenter

@Observable
@MainActor
public final class NoteLinkPickerPresenter {

    private var state: NoteLinkPickerState
    private let noteService: NoteService
    private let onSelected: (RelativePath, String) -> Void

    public init(
        folder: Folder,
        excluding: RelativePath,
        noteService: NoteService,
        onSelected: @escaping (RelativePath, String) -> Void
    ) {
        self.state = NoteLinkPickerState(folder: folder, excluding: excluding)
        self.noteService = noteService
        self.onSelected = onSelected
    }

    func viewModel() -> NoteLinkPickerViewModel {
        NoteLinkPickerViewModel(
            rows: state.results.compactMap { result in
                guard case .file(let file) = result.item, file.type == .markdown else { return nil }
                guard file.path != state.excluding else { return nil }
                return NoteLinkPickerViewModel.Row(
                    id: file.path.value,
                    name: file.name,
                    path: file.path.parent
                )
            }
        )
    }

    func on(_ action: NoteLinkPickerViewAction) {
        switch action {
        case .search(let query):
            Task { await search(query: query) }
        case .select(let id):
            guard let result = state.results.first(where: { $0.item.path.value == id }),
                  case .file(let file) = result.item
            else { return }
            let title = (file.name as NSString).deletingPathExtension
            onSelected(file.path, title)
        }
    }

    private func search(query: String) async {
        do {
            state.results = try await noteService.searchItems(in: state.folder, query: query)
        } catch {
            state.results = []
        }
    }
}
