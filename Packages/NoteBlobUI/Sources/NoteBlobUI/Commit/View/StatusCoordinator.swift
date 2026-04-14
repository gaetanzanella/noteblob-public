import SwiftUI
import NoteBlobKit

enum StatusPage: Hashable {
    case diff(DiffNavigationPayload)

    var filePath: String? {
        switch self {
        case .diff(let payload): payload.path.value
        }
    }
}

public struct StatusCoordinator: View {

    let presenterFactory: PresenterFactory
    let payload: CommitNavigationPayload
    let onDismiss: @MainActor () -> Void

    @State private var currentPage: StatusPage?

    public init(
        presenterFactory: PresenterFactory,
        payload: CommitNavigationPayload,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.presenterFactory = presenterFactory
        self.payload = payload
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            CommitView(
                presenter: presenterFactory.makeCommitPresenter(
                    payload: payload,
                    onRedirection: { redirection in
                        switch redirection {
                        case .dismiss:
                            onDismiss()
                        case .deselect:
                            currentPage = nil
                        case .viewDiff(let diffPayload):
                            currentPage = .diff(diffPayload)
                        }
                    }
                ),
                selection: { currentPage?.filePath }
            )
            .navigationDestination(item: $currentPage) { page in
                switch page {
                case .diff(let diffPayload):
                    DiffView(presenter: presenterFactory.makeDiffPresenter(payload: diffPayload))
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 350)
        #endif
    }
}
