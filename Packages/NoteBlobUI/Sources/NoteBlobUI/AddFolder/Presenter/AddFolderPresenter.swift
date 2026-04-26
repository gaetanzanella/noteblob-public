import Foundation
import NoteBlobKit

public enum AddFolderMode: Sendable {
    case local
    case github
}

public enum AddFolderViewAction {
    case editName(String)
    case editSearchQuery(String)
    case selectResult(String?)
    case add
    case next
}

public enum AddFolderRedirection {
    case dismiss
    case branchPicker(Repository)
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
    private var searchResults: [Repository] = []
    private var isSearching = false
    private var isAdding = false
    private var hasSearched = false
    private var errorMessage: String?
    private var searchTask: Task<Void, Never>?

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
            state = .results(searchResults.map { .init(id: "\($0.owner)/\($0.name)") })
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
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await search()
            }
        case .selectResult(let id):
            selectedResult = id
            #if os(iOS)
            on(.next)
            #endif
        case .add:
            Task { await add() }
        case .next:
            guard let id = selectedResult,
                  let repository = searchResults.first(where: { "\($0.owner)/\($0.name)" == id }) else { return }
            onRedirection(.branchPicker(repository))
        }
    }

    // MARK: - Private

    private func add() async {
        guard mode == .local else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        isAdding = true
        do {
            try await folderSyncService.add(Folder(localName: trimmed))
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
            searchResults = try await folderSyncService.searchRepositories(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        hasSearched = true
        isSearching = false
    }
}
