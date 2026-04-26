import SwiftUI

private enum NoteCoordinatorSheet: Identifiable {
    case linkPicker(NoteLinkPickerNavigationPayload)
    case urlLink(URLLinkNavigationPayload)
    case tableEditor(TableEditorNavigationPayload)

    var id: String {
        switch self {
        case .linkPicker: "linkPicker"
        case .urlLink: "urlLink"
        case .tableEditor: "tableEditor"
        }
    }
}

public struct NoteCoordinator: View {

    let presenterFactory: PresenterFactory
    let initialPayload: NoteNavigationPayload
    @Environment(\.dismiss) private var dismiss
    @State private var nav: NavigationState
    @State private var sheet: NoteCoordinatorSheet?

    public init(
        presenterFactory: PresenterFactory,
        payload: NoteNavigationPayload
    ) {
        self.presenterFactory = presenterFactory
        self.initialPayload = payload
        let nav = NavigationState(mode: .stack)
        nav.selectRootFolder(FolderNavigationPayload(folder: payload.folder))
        nav.selectNote(payload)
        self._nav = State(initialValue: nav)
    }

    public var body: some View {
        let syncPresenter = presenterFactory.makeSyncPresenter(folder: initialPayload.folder) { _ in }
        NavigationStack {
            if let note = nav.selectedNote {
                NoteView(
                    presenter: presenterFactory.makeNotePresenter(payload: note) { redirection in
                        switch redirection {
                        case .dismiss:
                            dismiss()
                        case .openNote(let payload):
                            nav.stackNote(payload)
                        case .pickLinkTarget(let payload):
                            sheet = .linkPicker(payload)
                        case .pickURLTarget(let payload):
                            sheet = .urlLink(payload)
                        case .pickTableTarget(let payload):
                            sheet = .tableEditor(payload)
                        }
                    },
                    syncPresenter: syncPresenter,
                    isFullScreen: false,
                    onToggleFullScreen: nil,
                    onSearchAppearanceChange: { _ in },
                    hasStackedNotes: nav.hasStackedNotes,
                    onGoBack: { nav.unstackNote() }
                )
                .id(note)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: NoteCoordinatorSheet) -> some View {
        switch sheet {
        case .linkPicker(let payload):
            NoteLinkPickerSheet(
                presenter: presenterFactory.makeNoteLinkPickerPresenter(
                    payload: NoteLinkPickerNavigationPayload(
                        folder: payload.folder,
                        excluding: payload.excluding,
                        onSelected: { path, title in
                            payload.onSelected(path, title)
                            self.sheet = nil
                        }
                    )
                )
            )
        case .urlLink(let payload):
            URLLinkSheet(
                presenter: presenterFactory.makeURLLinkPresenter(
                    payload: URLLinkNavigationPayload(
                        onConfirmed: { title, url in
                            payload.onConfirmed(title, url)
                            self.sheet = nil
                        }
                    )
                )
            )
        case .tableEditor(let payload):
            TableEditorView(
                presenter: presenterFactory.makeTableEditorPresenter(
                    payload: TableEditorNavigationPayload(
                        initialDraft: payload.initialDraft,
                        onConfirmed: { table in
                            payload.onConfirmed(table)
                            self.sheet = nil
                        }
                    )
                )
            )
        }
    }
}
