import SwiftUI

public struct CommitView: View {

    @State var presenter: CommitPresenter
    let selection: () -> String?

    public init(presenter: CommitPresenter, selection: @escaping () -> String?) {
        self._presenter = State(initialValue: presenter)
        self.selection = selection
    }

    public var body: some View {
        let vm = presenter.viewModel()
        let onAction: (CommitViewAction) -> Void = { presenter.on($0) }
        #if os(macOS)
        MacOSCommitView(vm: vm, selection: selection, onAction: onAction)
            .task { presenter.on(.load) }
        #else
        IOSCommitView(vm: vm, selection: selection, onAction: onAction)
            .task { presenter.on(.load) }
        #endif
    }
}
