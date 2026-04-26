import Foundation
import NoteBlobKit

public enum CreateRepositoryViewAction {
    case editName(String)
    case setPrivate(Bool)
    case create
    case dismissAlert
}

public enum CreateRepositoryRedirection {
    case dismiss
}

struct CreateRepositoryViewModel {
    let name: String
    let isPrivate: Bool
    let isCreating: Bool
    let errorMessage: String?
    let alert: AlertViewModel?
    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating
    }
    var canEdit: Bool { !isCreating }
}

private struct CreateRepositoryState {
    var name: String = ""
    var isPrivate: Bool = true
    var isCreating: Bool = false
    var errorMessage: String?
    var alert: AlertViewModel?
}

@Observable
@MainActor
public final class CreateRepositoryPresenter {

    private var state = CreateRepositoryState()
    private let folderSyncService: FolderSyncService
    private let onRedirection: (CreateRepositoryRedirection) -> Void

    public init(
        folderSyncService: FolderSyncService,
        onRedirection: @escaping (CreateRepositoryRedirection) -> Void
    ) {
        self.folderSyncService = folderSyncService
        self.onRedirection = onRedirection
    }

    func viewModel() -> CreateRepositoryViewModel {
        CreateRepositoryViewModel(
            name: state.name,
            isPrivate: state.isPrivate,
            isCreating: state.isCreating,
            errorMessage: state.errorMessage,
            alert: state.alert
        )
    }

    public func on(_ action: CreateRepositoryViewAction) {
        switch action {
        case .editName(let value):
            state.name = value
        case .setPrivate(let value):
            state.isPrivate = value
        case .create:
            Task { await create() }
        case .dismissAlert:
            state.alert = nil
        }
    }

    private func create() async {
        let trimmed = state.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        state.errorMessage = nil
        state.isCreating = true
        do {
            let description = String(
                localized: "create_repository.auto_description",
                bundle: .module
            )
            _ = try await folderSyncService.createRepository(
                name: trimmed,
                description: description,
                isPrivate: state.isPrivate
            )
            onRedirection(.dismiss)
        } catch NoteBlobError.folderAlreadyInstalled {
            state.alert = Alerts.folderAlreadyInstalled()
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isCreating = false
    }
}
