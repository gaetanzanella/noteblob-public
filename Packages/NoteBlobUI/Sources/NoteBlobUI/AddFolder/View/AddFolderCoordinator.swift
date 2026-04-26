import SwiftUI
import NoteBlobKit

enum AddFolderPage: Hashable {
    case local
    case github
    case branchPicker(Repository)
    case createRepository
}

public struct AddFolderCoordinator: View {

    let presenterFactory: PresenterFactory
    let onDismiss: @MainActor () -> Void

    @State private var path: [AddFolderPage] = []
    @State private var isShowingAuth = false

    public init(
        presenterFactory: PresenterFactory,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.presenterFactory = presenterFactory
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack(path: $path) {
            AddFolderMenuView(
                presenter: presenterFactory.makeAddFolderMenuPresenter(
                    onRedirection: { redirection in
                        switch redirection {
                        case .local:
                            path = [.local]
                        case .github:
                            path = [.github]
                        case .createRepository:
                            path = [.createRepository]
                        case .showAuth:
                            isShowingAuth = true
                        }
                    }
                ),
                selection: { path.first },
                onDismiss: onDismiss
            )
            #if os(macOS)
            .onAppear { path = [] }
            #endif
            .navigationDestination(for: AddFolderPage.self) { page in
                switch page {
                case .local:
                    LocalFolderView(
                        presenter: presenterFactory.makeAddFolderPresenter(
                            mode: .local,
                            onRedirection: { _ in onDismiss() }
                        )
                    )
                case .github:
                    GitHubSearchView(
                        presenter: presenterFactory.makeAddFolderPresenter(
                            mode: .github,
                            onRedirection: { redirection in
                                switch redirection {
                                case .dismiss:
                                    onDismiss()
                                case .branchPicker(let repository):
                                    path.append(.branchPicker(repository))
                                }
                            }
                        )
                    )
                case .branchPicker(let repository):
                    BranchPickerView(
                        presenter: presenterFactory.makeBranchPickerPresenter(
                            payload: BranchPickerNavigationPayload(repository: repository),
                            onRedirection: { _ in onDismiss() }
                        )
                    )
                case .createRepository:
                    CreateRepositoryView(
                        presenter: presenterFactory.makeCreateRepositoryPresenter(
                            onRedirection: { _ in onDismiss() }
                        )
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingAuth) {
            NavigationStack {
                AuthView(
                    presenter: presenterFactory.makeAuthPresenter(
                        payload: AuthenticateNavigationPayload(onAuthenticated: {})
                    ) { redirection in
                        switch redirection {
                        case .authenticated:
                            isShowingAuth = false
                        }
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            isShowingAuth = false
                        } label: {
                            Text("common.done", bundle: .module)
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }
}
