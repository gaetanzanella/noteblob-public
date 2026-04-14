import Foundation
import NoteBlobKit

// MARK: - Navigation

public enum SearchViewAction {
    case search(String)
    case select(String)
}

public enum SearchRedirection {
    case note(NoteNavigationPayload)
    case folder(FolderNavigationPayload)
    case quickLook(URL)
}

// MARK: - ViewModel

struct SearchViewModel {

    struct Row: Identifiable {
        let id: String
        let name: String
        let path: RelativePath
        let systemImage: String
        let snippet: AttributedString?
    }

    let rows: [Row]
}

// MARK: - State

private struct SearchState {
    let folder: Folder
    var results: [NoteSearchResult] = []
}

// MARK: - Presenter

@Observable
@MainActor
public final class SearchPresenter {

    private var state: SearchState
    private let noteService: NoteService
    private let onRedirection: (SearchRedirection) -> Void

    public init(
        folder: Folder,
        noteService: NoteService,
        onRedirection: @escaping (SearchRedirection) -> Void
    ) {
        self.state = SearchState(folder: folder)
        self.noteService = noteService
        self.onRedirection = onRedirection
    }

    func viewModel() -> SearchViewModel {
        SearchViewModel(
            rows: state.results.map { result in
                SearchViewModel.Row(
                    id: result.item.path.value,
                    name: result.item.name,
                    path: result.parent,
                    systemImage: result.item.isFolder ? "folder" : "doc.text",
                    snippet: result.snippet.map(Self.highlightedSnippet)
                )
            }
        )
    }

    // MARK: - Private

    private static func highlightedSnippet(_ snippet: ContentSearchSnippet) -> AttributedString {
        var attributed = AttributedString(snippet.text)
        attributed.foregroundColor = .secondary
        let startOffset = snippet.text.distance(from: snippet.text.startIndex, to: snippet.matchRange.lowerBound)
        let endOffset = snippet.text.distance(from: snippet.text.startIndex, to: snippet.matchRange.upperBound)
        let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: startOffset)
        let attrEnd = attributed.index(attributed.startIndex, offsetByCharacters: endOffset)
        attributed[attrStart..<attrEnd].font = .caption.bold()
        attributed[attrStart..<attrEnd].foregroundColor = .primary
        return attributed
    }

    public func on(_ action: SearchViewAction) {
        switch action {
        case .search(let query):
            Task { await search(query: query) }
        case .select(let id):
            guard let result = state.results.first(where: { $0.item.path.value == id }) else { return }
            switch result.item {
            case .folder:
                onRedirection(.folder(FolderNavigationPayload(folder: state.folder, path: result.item.path)))
            case .file(let file):
                if file.type == .markdown {
                    onRedirection(.note(NoteNavigationPayload(folder: state.folder, path: result.item.path)))
                } else {
                    onRedirection(.quickLook(noteService.fileURL(in: state.folder, at: result.item.path)))
                }
            }
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
