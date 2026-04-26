import Foundation
import NoteBlobKit

public struct BranchPickerNavigationPayload {
    let repository: Repository
}

public enum BranchPickerViewAction {
    case select(String?)
    case confirm
    case dismissAlert
}

public enum BranchPickerRedirection {
    case dismiss
}

struct BranchPickerViewModel {
    let branches: [String]
    let selectedBranch: String?
    let isLoading: Bool
    let isAdding: Bool
    let errorMessage: String?
    let alert: AlertViewModel?
    var canConfirm: Bool { selectedBranch != nil && !isAdding }
    var canSelect: Bool { !isAdding }
}

// MARK: - State

private struct BranchPickerState {

    enum LoadingState {
        case loading
        case loaded([String])
        case failed(String)
    }

    let payload: BranchPickerNavigationPayload
    var loadingState: LoadingState = .loading
    var selectedBranch: String?
    var isAdding = false
    var alert: AlertViewModel?
}

// MARK: - Presenter

@Observable
@MainActor
public final class BranchPickerPresenter {

    private var state: BranchPickerState
    private let folderSyncService: FolderSyncService
    private let onRedirection: (BranchPickerRedirection) -> Void
    private let mapper = BranchPickerViewModelMapper()

    public init(
        payload: BranchPickerNavigationPayload,
        folderSyncService: FolderSyncService,
        onRedirection: @escaping (BranchPickerRedirection) -> Void
    ) {
        self.state = BranchPickerState(payload: payload)
        self.folderSyncService = folderSyncService
        self.onRedirection = onRedirection
    }

    func viewModel() -> BranchPickerViewModel {
        mapper.map(state)
    }

    public func on(_ action: BranchPickerViewAction) {
        switch action {
        case .select(let branch):
            state.selectedBranch = branch
        case .confirm:
            Task { await add() }
        case .dismissAlert:
            state.alert = nil
        }
    }

    public func load() async {
        state.loadingState = .loading
        do {
            let branches = try await folderSyncService.listBranches(for: state.payload.repository)
            state.loadingState = .loaded(branches)
            if let main = branches.first(where: { $0 == "main" || $0 == "master" }) {
                state.selectedBranch = main
            } else {
                state.selectedBranch = branches.first
            }
        } catch {
            state.loadingState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func add() async {
        guard let selectedBranch = state.selectedBranch else { return }
        state.isAdding = true
        do {
            let folder = Folder(repository: state.payload.repository, defaultBranch: selectedBranch)
            try await folderSyncService.add(folder)
            onRedirection(.dismiss)
        } catch NoteBlobError.folderAlreadyInstalled {
            state.alert = Alerts.folderAlreadyInstalled()
        } catch {
            state.alert = .error(error.localizedDescription)
        }
        state.isAdding = false
    }
}

// MARK: - Mapper

private struct BranchPickerViewModelMapper {

    func map(_ state: BranchPickerState) -> BranchPickerViewModel {
        let branches: [String]
        let isLoading: Bool
        let errorMessage: String?
        switch state.loadingState {
        case .loading:
            branches = []
            isLoading = true
            errorMessage = nil
        case .loaded(let items):
            branches = items
            isLoading = false
            errorMessage = nil
        case .failed(let message):
            branches = []
            isLoading = false
            errorMessage = message
        }
        return BranchPickerViewModel(
            branches: branches,
            selectedBranch: state.selectedBranch,
            isLoading: isLoading,
            isAdding: state.isAdding,
            errorMessage: errorMessage,
            alert: state.alert
        )
    }
}
