import Foundation
import NoteBlobKit

// MARK: - Navigation

public struct DiffNavigationPayload: Hashable {
    public let folder: Folder
    public let path: RelativePath
    public let changeKind: DiffChangeKind

    public init(folder: Folder, path: RelativePath, changeKind: DiffChangeKind) {
        self.folder = folder
        self.path = path
        self.changeKind = changeKind
    }
}

public enum DiffChangeKind: Hashable {
    case added
    case modified
    case deleted
}

public enum DiffViewAction {
    case load
}

// MARK: - ViewModel

struct DiffViewModel {

    struct Hunk: Identifiable {
        let id: Int
        let header: String
        let lines: [Line]
    }

    struct Line: Identifiable {
        let id: Int
        let kind: FileDiff.Hunk.Line.Kind
        let content: String
    }

    let title: String
    let hunks: [Hunk]
    let isLoading: Bool
    let errorMessage: String?
}

// MARK: - State

private struct DiffState {
    let payload: DiffNavigationPayload
    var fileDiff: FileDiff?
    var isLoading = false
    var errorMessage: String?
}

// MARK: - Presenter

@Observable
@MainActor
public final class DiffPresenter {

    private var state: DiffState
    private let folderSyncService: FolderSyncService

    public init(
        payload: DiffNavigationPayload,
        folderSyncService: FolderSyncService
    ) {
        self.state = DiffState(payload: payload)
        self.folderSyncService = folderSyncService
    }

    func viewModel() -> DiffViewModel {
        var lineID = 0
        let hunks: [DiffViewModel.Hunk] = (state.fileDiff?.hunks ?? []).enumerated().map { index, hunk in
            DiffViewModel.Hunk(
                id: index,
                header: hunk.header,
                lines: hunk.lines.map { line in
                    defer { lineID += 1 }
                    return DiffViewModel.Line(
                        id: lineID,
                        kind: line.kind,
                        content: line.content
                    )
                }
            )
        }

        return DiffViewModel(
            title: state.payload.path.lastComponent,
            hunks: hunks,
            isLoading: state.isLoading,
            errorMessage: state.errorMessage
        )
    }

    public func on(_ action: DiffViewAction) {
        switch action {
        case .load:
            Task { await load() }
        }
    }

    private func load() async {
        state.isLoading = true
        do {
            state.fileDiff = try await folderSyncService.diff(
                for: state.payload.folder,
                at: state.payload.path
            )
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isLoading = false
    }
}
