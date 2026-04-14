import SwiftUI

public struct NoteCoordinator: View {

    let presenterFactory: PresenterFactory
    let payload: NoteNavigationPayload
    @Environment(\.dismiss) private var dismiss

    public init(
        presenterFactory: PresenterFactory,
        payload: NoteNavigationPayload
    ) {
        self.presenterFactory = presenterFactory
        self.payload = payload
    }

    public var body: some View {
        let syncPresenter = presenterFactory.makeSyncPresenter(folder: payload.folder) { _ in }
        NavigationStack {
            NoteView(
                presenter: presenterFactory.makeNotePresenter(payload: payload) {
                    switch $0 {
                    case .dismiss:
                        dismiss()
                    }
                },
                syncPresenter: syncPresenter,
                onSearchAppearanceChange: { _ in }
            )
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
