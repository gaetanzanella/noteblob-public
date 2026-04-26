import Foundation
import NoteBlobKit

public enum AddFolderMenuViewAction: Hashable {
    case selectLocal
    case selectGitHub
    case selectCreateRepository
}

public enum AddFolderMenuRedirection {
    case local
    case github
    case createRepository
    case showAuth
}

struct AddFolderMenuViewModel {
    let isAuthenticated: Bool
}

@Observable
@MainActor
public final class AddFolderMenuPresenter {

    private let authService: AuthService
    private let onRedirection: (AddFolderMenuRedirection) -> Void

    public init(
        authService: AuthService,
        onRedirection: @escaping (AddFolderMenuRedirection) -> Void
    ) {
        self.authService = authService
        self.onRedirection = onRedirection
    }

    func viewModel() -> AddFolderMenuViewModel {
        AddFolderMenuViewModel(isAuthenticated: authService.isAuthenticated)
    }

    public func on(_ action: AddFolderMenuViewAction) {
        switch action {
        case .selectLocal:
            onRedirection(.local)
        case .selectGitHub:
            if authService.isAuthenticated {
                onRedirection(.github)
            } else {
                onRedirection(.showAuth)
            }
        case .selectCreateRepository:
            if authService.isAuthenticated {
                onRedirection(.createRepository)
            } else {
                onRedirection(.showAuth)
            }
        }
    }
}
