import Foundation
import NoteBlobKit

// MARK: - Navigation

public enum CommitViewAction {
    case load
    case editMessage(String)
    case commit
    case commitAndPush
    case commitPushAndMerge
    case done
    case discard
    case discardFile(String)
    case selectFile(String?)
    case push
    case pushAndMerge
    case pull
    case merge
}

public enum CommitRedirection {
    case dismiss
    case deselect
    case viewDiff(DiffNavigationPayload)
}

// MARK: - ViewModel

struct CommitViewModel {

    enum Mode {
        case loading
        case localChanges
        case pushNeeded
        case pullNeeded
        case upToDate
        case readyToMerge
        case notBacked
    }

    enum ChangeKind {
        case added
        case modified
        case deleted
    }

    struct Row: Identifiable {
        let id: String
        let path: String
        let kind: ChangeKind
    }

    struct CommitRow: Identifiable {
        let id: String
        let message: String
        let date: Date
        let isPushed: Bool
    }

    let mode: Mode
    let commitMessage: String
    let rows: [Row]
    let branchName: String
    let commitRows: [CommitRow]
    let isLoading: Bool
    let isGeneratingMessage: Bool
    let errorMessage: String?
    var canCommit: Bool {
        !commitMessage.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading && !isGeneratingMessage
    }
}

// MARK: - State

private struct CommitState {
    let payload: CommitNavigationPayload
    var syncStatus: SyncStatus?
    var commitMessage = ""
    var changes: [Change] = []
    var commitLog: [CommitInfo] = []
    var unpushedCount = 0
    var isLoading = false
    var isGeneratingMessage = false
    var errorMessage: String?
}

// MARK: - Presenter

@Observable
@MainActor
public final class CommitPresenter {

    private var state: CommitState
    private let folderSyncService: FolderSyncService
    private let aiAssistantService: AIAssistantService
    private let onRedirection: (CommitRedirection) -> Void

    public init(
        payload: CommitNavigationPayload,
        folderSyncService: FolderSyncService,
        aiAssistantService: AIAssistantService,
        onRedirection: @escaping (CommitRedirection) -> Void
    ) {
        self.state = CommitState(payload: payload)
        self.folderSyncService = folderSyncService
        self.aiAssistantService = aiAssistantService
        self.onRedirection = onRedirection
    }

    func viewModel() -> CommitViewModel {
        CommitViewModel(
            mode: mapMode(state.syncStatus),
            commitMessage: state.commitMessage,
            rows: state.changes.map { change in
                CommitViewModel.Row(
                    id: change.path,
                    path: change.path,
                    kind: mapChangeKind(change)
                )
            },
            branchName: state.syncStatus?.branch.name ?? "",
            commitRows: state.commitLog.enumerated().map { index, commit in
                CommitViewModel.CommitRow(
                    id: commit.id,
                    message: commit.message,
                    date: commit.date,
                    isPushed: index >= state.unpushedCount
                )
            },
            isLoading: state.isLoading,
            isGeneratingMessage: state.isGeneratingMessage,
            errorMessage: state.errorMessage
        )
    }

    public func on(_ action: CommitViewAction) {
        switch action {
        case .load:
            Task { await load() }
        case .editMessage(let value):
            state.commitMessage = value
        case .commit:
            Task { await commit() }
        case .commitAndPush:
            Task { await commitAndPush() }
        case .commitPushAndMerge:
            Task { await commitPushAndMerge() }
        case .done:
            onRedirection(.dismiss)
        case .discard:
            Task { await discard() }
        case .discardFile(let path):
            Task { await discardFile(path) }
        case .selectFile(let path):
            guard let path, let change = state.changes.first(where: { $0.path == path }) else {
                onRedirection(.deselect)
                return
            }
            let kind: DiffChangeKind = switch change {
            case .added: .added
            case .modified: .modified
            case .deleted: .deleted
            }
            onRedirection(.viewDiff(DiffNavigationPayload(
                folder: state.payload.folder,
                path: RelativePath(path),
                changeKind: kind
            )))
        case .push:
            Task { await push() }
        case .pushAndMerge:
            Task { await pushAndMerge() }
        case .pull:
            Task { await pull() }
        case .merge:
            Task { await merge() }
        }
    }

    private func mapMode(_ status: SyncStatus?) -> CommitViewModel.Mode {
        guard let status else { return .loading }
        return switch status.state {
        case .upToDate: .upToDate
        case .localChanges: .localChanges
        case .pushNeeded: .pushNeeded
        case .pullNeeded: .pullNeeded
        case .readyToMerge: .readyToMerge
        case .notBacked: .notBacked
        }
    }

    private func mapChangeKind(_ change: Change) -> CommitViewModel.ChangeKind {
        switch change {
        case .added: .added
        case .modified: .modified
        case .deleted: .deleted
        }
    }

    private func load() async {
        state.isLoading = true
        state.syncStatus = nil
        state.changes = []
        state.commitLog = []
        do {
            let status = try await folderSyncService.status(for: state.payload.folder)
            state.syncStatus = status
            switch status.state {
            case .localChanges:
                state.changes = try await folderSyncService.pendingChanges(for: state.payload.folder)
            case .pushNeeded, .readyToMerge:
                state.commitLog = try await folderSyncService.commitLog(for: state.payload.folder)
                state.unpushedCount = try await folderSyncService.unpushedCommitCount(for: state.payload.folder)
            default:
                break
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isLoading = false

        if !state.changes.isEmpty {
            await generateMessage()
        }
    }

    private func generateMessage() async {
        guard await aiAssistantService.isAvailable() else { return }
        state.isGeneratingMessage = true
        do {
            let message = try await aiAssistantService.generateCommitMessage(for: state.changes)
            state.commitMessage = message
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isGeneratingMessage = false
    }

    private func discard() async {
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.discardChanges(in: state.payload.folder)
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            state.isLoading = false
        }
    }

    private func discardFile(_ path: String) async {
        state.errorMessage = nil
        do {
            try await folderSyncService.discardChange(in: state.payload.folder, at: RelativePath(path))
            state.changes.removeAll { $0.path == path }
            if state.changes.isEmpty {
                onRedirection(.dismiss)
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func commit() async {
        guard !state.commitMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.commit(
                in: state.payload.folder,
                message: state.commitMessage
            )
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            state.isLoading = false
        }
    }

    private func commitAndPush() async {
        guard !state.commitMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.commitAndPush(
                in: state.payload.folder,
                message: state.commitMessage
            )
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            await load()
        }
    }

    private func commitPushAndMerge() async {
        guard !state.commitMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.commitPushAndMerge(
                in: state.payload.folder,
                message: state.commitMessage
            )
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            await load()
        }
    }

    private func push() async {
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.push(state.payload.folder)
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            state.isLoading = false
        }
    }

    private func pushAndMerge() async {
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.pushAndMerge(state.payload.folder)
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            await load()
        }
    }

    private func pull() async {
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.pull(state.payload.folder)
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            state.isLoading = false
        }
    }

    private func merge() async {
        state.isLoading = true
        state.errorMessage = nil
        do {
            try await folderSyncService.merge(state.payload.folder)
            state.isLoading = false
            onRedirection(.dismiss)
        } catch {
            state.errorMessage = error.localizedDescription
            state.isLoading = false
        }
    }

}
