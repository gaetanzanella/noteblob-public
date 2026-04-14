import Foundation
import NoteBlobKit

public enum AddFolderMode: Sendable {
    case local
    case github
}

public enum AddFolderViewAction {
    case editName(String)
    case editSearchQuery(String)
    case search
    case selectResult(String?)
    case add
}

public enum AddFolderRedirection {
    case dismiss
}

struct LocalFolderViewModel {
    let name: String
    let isAdding: Bool
    let errorMessage: String?
    var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isAdding
    }
}

struct GitHubSearchViewModel {

    enum State {
        case idle
        case searching
        case noResults
        case results([Row])
    }

    struct Row: Identifiable {
        let id: String
    }

    let searchQuery: String
    let selectedResult: String?
    let state: State
    let isAdding: Bool
    let errorMessage: String?
    var canAdd: Bool { selectedResult != nil && !isAdding }
}

@Observable
@MainActor
public final class AddFolderPresenter {

    private let mode: AddFolderMode
    private let folderSyncService: FolderSyncService
    private let onRedirection: (AddFolderRedirection) -> Void

    private var name = ""
    private var searchQuery = ""
    private var selectedResult: String?
    private var searchResults: [Folder] = []
    private var isSearching = false
    private var isAdding = false
    private var hasSearched = false
    private var errorMessage: String?

    public init(
        mode: AddFolderMode,
        folderSyncService: FolderSyncService,
        onRedirection: @escaping (AddFolderRedirection) -> Void
    ) {
        self.mode = mode
        self.folderSyncService = folderSyncService
        self.onRedirection = onRedirection
    }

    func localViewModel() -> LocalFolderViewModel {
        LocalFolderViewModel(name: name, isAdding: isAdding, errorMessage: errorMessage)
    }

    func githubViewModel() -> GitHubSearchViewModel {
        let state: GitHubSearchViewModel.State
        if isSearching {
            state = .searching
        } else if hasSearched && searchResults.isEmpty {
            state = .noResults
        } else if !searchResults.isEmpty {
            state = .results(searchResults.map { .init(id: $0.id) })
        } else {
            state = .idle
        }
        return GitHubSearchViewModel(
            searchQuery: searchQuery,
            selectedResult: selectedResult,
            state: state,
            isAdding: isAdding,
            errorMessage: errorMessage
        )
    }

    public func on(_ action: AddFolderViewAction) {
        switch action {
        case .editName(let value):
            name = value
        case .editSearchQuery(let value):
            searchQuery = value
            selectedResult = nil
        case .search:
            Task { await search() }
        case .selectResult(let id):
            selectedResult = id
        case .add:
            Task { await add() }
        }
    }

    // MARK: - Private

    private func add() async {
        errorMessage = nil
        isAdding = true
        do {
            switch mode {
            case .local:
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    isAdding = false
                    return
                }
                try await folderSyncService.add(Folder(localName: trimmed))
            case .github:
                guard let id = selectedResult,
                      let folder = searchResults.first(where: { $0.id == id }) else {
                    isAdding = false
                    return
                }
                try await folderSyncService.add(folder)
            }
            onRedirection(.dismiss)
        } catch {
            errorMessage = error.localizedDescription
        }
        isAdding = false
    }

    private func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }
        isSearching = true
        errorMessage = nil
        selectedResult = nil
        do {
            searchResults = try await folderSyncService.searchFolders(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        hasSearched = true
        isSearching = false
    }
}
