import SwiftUI
import NoteBlobKit

enum AddFolderPage: Hashable {
    case local
    case github
}

public struct AddFolderCoordinator: View {

    let presenterFactory: PresenterFactory
    let onDismiss: @MainActor () -> Void

    @State private var currentPage: AddFolderPage?
    @State private var isShowingAuth = false

    public init(
        presenterFactory: PresenterFactory,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.presenterFactory = presenterFactory
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            AddFolderMenuView(
                presenter: presenterFactory.makeAddFolderMenuPresenter(
                    onRedirection: { redirection in
                        switch redirection {
                        case .local:
                            currentPage = .local
                        case .github:
                            currentPage = .github
                        case .showAuth:
                            isShowingAuth = true
                        }
                    }
                ),
                selection: { currentPage },
                onDismiss: onDismiss
            )
            .navigationDestination(item: $currentPage) { page in
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
                            onRedirection: { _ in onDismiss() }
                        )
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingAuth) {
            NavigationStack {
                AuthView(
                    presenter: presenterFactory.makeAuthPresenter { redirection in
                        switch redirection {
                        case .authenticated:
                            isShowingAuth = false
                            currentPage = .github
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
