import Foundation
import NoteBlobKit
import TextEditorKit

// MARK: - Navigation

enum NoteViewAction {
    case load
    case edit
    case stopEditing
    case cancel
    case toggleRawText
    case applyEditorAction(DocumentEditorAction)
    case openNoteLink(URL)
}

public enum NoteRedirection {
    case dismiss
    case openNote(NoteNavigationPayload)
    case pickLinkTarget(NoteLinkPickerNavigationPayload)
    case pickURLTarget(URLLinkNavigationPayload)
    case pickTableTarget(TableEditorNavigationPayload)
}

// MARK: - State

private struct NoteState {
    let payload: NoteNavigationPayload
    var previewMode: PreviewMode = .formatted
    var errorMessage: String?
    var latestChangeDate: Date?
}

// MARK: - Presenter

@Observable
@MainActor
public final class NotePresenter: DocumentEditorDelegate {

    enum Mode {
        case preview(content: String)
        case editing(editor: DocumentEditor)
    }

    private(set) var mode: Mode = .preview(content: "")
    private(set) var shouldRequestReview = false
    var actionVersion = 0

    private var state: NoteState
    private let noteService: NoteService
    private let onRedirection: (NoteRedirection) -> Void
    private var syncSubscription: SyncEventPublisher.Subscription?
    private var noteSubscription: NoteEventPublisher.Subscription?

    public init(
        payload: NoteNavigationPayload,
        noteService: NoteService,
        syncEventPublisher: SyncEventPublisher,
        noteEventPublisher: NoteEventPublisher,
        onRedirection: @escaping (NoteRedirection) -> Void
    ) {
        self.state = NoteState(payload: payload)
        self.noteService = noteService
        self.onRedirection = onRedirection
        subscribeToSyncEvents(syncEventPublisher, folder: payload.folder)
        subscribeToNoteEvents(noteEventPublisher, folder: payload.folder)
    }

    func viewModel() -> NoteViewModel {
        _ = actionVersion  // trigger SwiftUI observation on action state changes
        let vmMode: NoteViewModel.Mode
        let toolbarActions: [ToolbarAction]
        let menuActions: [ToolbarAction]
        let undoRedoActions: [ToolbarAction]
        switch mode {
        case .preview:
            vmMode = .preview(state.previewMode)
            toolbarActions = []
            menuActions = []
            undoRedoActions = []
        case .editing(let editor):
            vmMode = .editing
            toolbarActions = makeToolbarActions(for: editor)
            menuActions = makeMenuActions(for: editor)
            undoRedoActions = makeUndoRedoActions(for: editor)
        }
        return NoteViewModel(
            latestChangeDate: state.latestChangeDate,
            title: state.payload.path.lastComponent,
            mode: vmMode,
            toolbarActions: toolbarActions,
            menuActions: menuActions,
            undoRedoActions: undoRedoActions,
            errorMessage: state.errorMessage
        )
    }

    func on(_ action: NoteViewAction) {
        switch action {
        case .load:
            load()
        case .edit:
            startEditing()
        case .stopEditing:
            mode = .preview(content: readContent())
        case .cancel:
            if case .editing(let editor) = mode {
                editor.cancelEditing()
            }
            mode = .preview(content: readContent())
        case .toggleRawText:
            switch state.previewMode {
            case .formatted: state.previewMode = .raw
            case .raw: state.previewMode = .formatted
            }
        case .applyEditorAction(let action):
            if case .editing(let editor) = mode {
                editor.apply(action)
            }
        case .openNoteLink(let url):
            guard let link = NoteLink(url: url) else { return }
            onRedirection(.openNote(NoteNavigationPayload(folder: state.payload.folder, path: link.path)))
        }
    }

    // MARK: - Private

    private func beginPickLinkTarget() {
        guard case .editing = mode else { return }
        let payload = NoteLinkPickerNavigationPayload(
            folder: state.payload.folder,
            excluding: state.payload.path,
            onSelected: { [weak self] path, title in
                self?.insertLink(to: path, title: title)
            }
        )
        onRedirection(.pickLinkTarget(payload))
    }

    private func insertLink(to path: RelativePath, title: String) {
        guard case .editing(let editor) = mode else { return }
        let link = NoteLink(path: path)
        editor.apply(.insert(.link(target: link.encodedPath, title: title)))
    }

    private func beginPickURLTarget() {
        guard case .editing = mode else { return }
        let payload = URLLinkNavigationPayload(
            onConfirmed: { [weak self] title, url in
                self?.insertURLLink(url: url, title: title)
            }
        )
        onRedirection(.pickURLTarget(payload))
    }

    private func insertURLLink(url: URL, title: String) {
        guard case .editing(let editor) = mode else { return }
        editor.apply(.insert(.link(target: url.absoluteString, title: title)))
    }

    private func insertTable(from draft: TableDraft) {
        guard case .editing(let editor) = mode else { return }
        let table = MarkdownTable(headers: draft.headers, rows: draft.rows)
        editor.apply(.insert(.table(table)))
    }

    private func readContent() -> String {
        (try? noteService.readNote(in: state.payload.folder, at: state.payload.path)) ?? ""
    }

    private func fileURL() -> URL {
        noteService.fileURL(in: state.payload.folder, at: state.payload.path)
    }

    private func load() {
        do {
            switch mode {
            case .editing(let editor):
                try editor.load(from: fileURL())
            case .preview:
                let content = try noteService.readNote(
                    in: state.payload.folder, at: state.payload.path)
                mode = .preview(content: content)
                shouldRequestReview = noteService.shouldRequestReview()
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    startEditing()
                }
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
        Task {
            let note = try? await noteService.note(in: state.payload.folder, at: state.payload.path)
            state.latestChangeDate = note?.latestChangeDate
        }
    }

    private func startEditing() {
        if case .editing = mode { return }
        do {
            let editor = DocumentEditor()
            editor.delegate = self
            try editor.load(from: fileURL())
            mode = .editing(editor: editor)
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    // MARK: - DocumentEditorDelegate

    public func documentEditorDidUpdateActions(_ editor: DocumentEditor) {
        actionVersion += 1
    }

    public func documentEditor(
        _ editor: DocumentEditor,
        requestTableEditing request: TableEditingRequest
    ) {
        let initial = TableDraft(
            headers: request.currentTable.headers,
            rows: request.currentTable.rows
        )
        let payload = TableEditorNavigationPayload(
            initialDraft: initial,
            onConfirmed: { [weak self] draft in
                self?.insertTable(from: draft)
            }
        )
        onRedirection(.pickTableTarget(payload))
    }

    private let headingKeys: [String.LocalizationValue] = [
        "editor.heading_1", "editor.heading_2", "editor.heading_3", "editor.heading_4",
    ]

    private func makeToolbarActions(for editor: DocumentEditor) -> [ToolbarAction] {
        func action(_ editorAction: DocumentEditorAction) -> () -> Void {
            { [weak self] in self?.on(.applyEditorAction(editorAction)) }
        }

        let headingLevels = 1...headingKeys.count
        let anyHeadingActive = headingLevels.contains { editor.isActive(.format(.heading($0))) }
        return [
            ToolbarAction(
                id: "heading",
                kind: .menu(
                    systemImage: "textformat.size",
                    options: headingKeys.enumerated().map { index, key in
                        let level = index + 1
                        return ToolbarAction.MenuOption(
                            id: "h\(level)",
                            title: .localized(key),
                            systemImage: nil,
                            isActive: editor.isActive(.format(.heading(level))),
                            isEnabled: editor.isEnabled(.format(.heading(level))),
                            action: action(.format(.heading(level)))
                        )
                    }
                ),
                isActive: anyHeadingActive,
                isEnabled: editor.isEnabled(.format(.heading(1))),
                keyboardShortcut: nil,
                action: {}
            ),
            ToolbarAction(
                id: "bold", kind: .button(systemImage: "bold"),
                isActive: editor.isActive(.format(.bold)),
                isEnabled: editor.isEnabled(.format(.bold)),
                keyboardShortcut: .init("b"),
                action: action(.format(.bold))),
            ToolbarAction(
                id: "italic", kind: .button(systemImage: "italic"),
                isActive: editor.isActive(.format(.italic)),
                isEnabled: editor.isEnabled(.format(.italic)),
                keyboardShortcut: .init("i"),
                action: action(.format(.italic))),
            ToolbarAction(
                id: "strikethrough", kind: .button(systemImage: "strikethrough"),
                isActive: editor.isActive(.format(.strikethrough)),
                isEnabled: editor.isEnabled(.format(.strikethrough)),
                keyboardShortcut: .init("s"),
                action: action(.format(.strikethrough))),
            ToolbarAction(
                id: "inlineCode",
                kind: .button(systemImage: "chevron.left.forwardslash.chevron.right"),
                isActive: editor.isActive(.format(.inlineCode)),
                isEnabled: editor.isEnabled(.format(.inlineCode)),
                keyboardShortcut: .init("e"),
                action: action(.format(.inlineCode))),
            ToolbarAction(
                id: "codeBlock", kind: .button(systemImage: "curlybraces"),
                isActive: editor.isActive(.format(.codeBlock)),
                isEnabled: editor.isEnabled(.format(.codeBlock)),
                action: action(.format(.codeBlock))),
            ToolbarAction(
                id: "list", kind: .button(systemImage: "list.bullet"),
                isActive: editor.isActive(.format(.list)),
                isEnabled: editor.isEnabled(.format(.list)),
                keyboardShortcut: .init("l"),
                action: action(.format(.list))),
            ToolbarAction(
                id: "todoList", kind: .button(systemImage: "checklist"),
                isActive: editor.isActive(.format(.todoList)),
                isEnabled: editor.isEnabled(.format(.todoList)),
                action: action(.format(.todoList))),
            ToolbarAction(
                id: "link",
                kind: .menu(systemImage: "link", options: [
                    ToolbarAction.MenuOption(
                        id: "note",
                        title: String.localized("note.link.menu.note"),
                        systemImage: "doc.text",
                        isActive: false,
                        isEnabled: true,
                        action: { [weak self] in self?.beginPickLinkTarget() }
                    ),
                    ToolbarAction.MenuOption(
                        id: "url",
                        title: String.localized("note.link.menu.url"),
                        systemImage: "link",
                        isActive: false,
                        isEnabled: true,
                        action: { [weak self] in self?.beginPickURLTarget() }
                    ),
                ]),
                isActive: false,
                isEnabled: true,
                keyboardShortcut: .init("k"),
                action: {}),
            ToolbarAction(
                id: "table", kind: .button(systemImage: "tablecells"),
                isActive: editor.isActive(.editTable),
                isEnabled: editor.isEnabled(.editTable),
                action: action(.editTable)),
            ToolbarAction(
                id: "dedent", kind: .button(systemImage: "decrease.indent"),
                isActive: editor.isActive(.dedent),
                isEnabled: editor.isEnabled(.dedent),
                keyboardShortcut: .init("\t", shift: true),
                action: action(.dedent)),
            ToolbarAction(
                id: "escape", kind: .button(systemImage: ""),
                isActive: false, isEnabled: true, isHidden: true,
                keyboardShortcut: .init("\u{1B}", command: false),
                action: { [weak self] in self?.on(.stopEditing) }),
        ]
    }

    private func makeUndoRedoActions(for editor: DocumentEditor) -> [ToolbarAction] {
        [
            ToolbarAction(
                id: "undo", kind: .button(systemImage: "arrow.uturn.backward"),
                isActive: false,
                isEnabled: editor.isEnabled(.undo),
                keyboardShortcut: .init("z"),
                localizedTitle: "note.menu.undo",
                action: { [weak self] in self?.on(.applyEditorAction(.undo)) }),
            ToolbarAction(
                id: "redo", kind: .button(systemImage: "arrow.uturn.forward"),
                isActive: false,
                isEnabled: editor.isEnabled(.redo),
                keyboardShortcut: .init("z", shift: true),
                localizedTitle: "note.menu.redo",
                action: { [weak self] in self?.on(.applyEditorAction(.redo)) }),
        ]
    }

    private func makeMenuActions(for editor: DocumentEditor) -> [ToolbarAction] {
        func action(_ editorAction: DocumentEditorAction) -> () -> Void {
            { [weak self] in self?.on(.applyEditorAction(editorAction)) }
        }
        return [
            ToolbarAction(
                id: "formatDocument", kind: .button(systemImage: "text.alignleft"),
                isActive: editor.isActive(.formatDocument),
                isEnabled: editor.isEnabled(.formatDocument),
                keyboardShortcut: nil,
                localizedTitle: "note.menu.format", action: action(.formatDocument))
        ]
    }

    private func subscribeToSyncEvents(_ publisher: SyncEventPublisher, folder: Folder) {
        syncSubscription = publisher.subscribe { [weak self] event in
            guard let self else { return }
            switch event {
            case .didPull(let eventFolder),
                 .didMerge(let eventFolder),
                 .didDiscard(let eventFolder),
                 .didDelete(let eventFolder):
                guard eventFolder.id == folder.id else { return }
                Task { @MainActor in
                    self.handleExternalChange()
                }
            }
        }
    }

    private func subscribeToNoteEvents(_ publisher: NoteEventPublisher, folder: Folder) {
        noteSubscription = publisher.subscribe { [weak self] event in
            guard let self else { return }
            switch event {
            case .didDelete(let eventFolder, _):
                guard eventFolder.id == folder.id else { return }
                Task { @MainActor in
                    self.handleExternalChange()
                }
            }
        }
    }

    private func handleExternalChange() {
        guard noteService.fileExists(in: state.payload.folder, at: state.payload.path) else {
            onRedirection(.dismiss)
            return
        }
        load()
    }
}
