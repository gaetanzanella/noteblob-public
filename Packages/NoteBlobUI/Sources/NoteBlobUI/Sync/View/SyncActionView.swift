import SwiftUI

enum SyncAction {
    case none
    case localChanges(Int)
    case push
    case pull
    case merge
    case notBacked
    case error(String)
}

struct SyncActionView: View {

    @State var presenter: SyncPresenter

    var body: some View {
        let vm = presenter.viewModel()
        Button { presenter.on(.showDetail) } label: {
            if vm.isLoading {
                ProgressView().controlSize(.small)
            } else {
                syncIcon(for: vm.syncAction)
            }
        }
        .onAppear { presenter.on(.load) }
    }

    @ViewBuilder
    private func syncIcon(for action: SyncAction) -> some View {
        switch action {
        case .none:
            Image(systemName: "checkmark.circle")
        case .localChanges:
            Image(systemName: "arrow.triangle.2.circlepath")
        case .push:
            Image(systemName: "arrow.up.circle")
        case .pull:
            Image(systemName: "arrow.down.circle")
        case .merge:
            Image(systemName: "arrow.triangle.merge")
        case .notBacked:
            Image(systemName: "exclamationmark.triangle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }
}
