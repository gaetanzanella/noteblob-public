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
}

public enum NoteRedirection {
    case dismiss
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
        switch mode {
        case .preview:
            vmMode = .preview(state.previewMode)
            toolbarActions = []
            menuActions = []
        case .editing(let editor):
            vmMode = .editing
            toolbarActions = makeToolbarActions(for: editor)
            menuActions = makeMenuActions(for: editor)
        }
        return NoteViewModel(
            latestChangeDate: state.latestChangeDate,
            title: state.payload.path.lastComponent,
            mode: vmMode,
            toolbarActions: toolbarActions,
            menuActions: menuActions,
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
        }
    }

    // MARK: - Private

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

    private let headingKeys: [String.LocalizationValue] = [
        "editor.heading_1", "editor.heading_2", "editor.heading_3", "editor.heading_4",
    ]

    private func makeToolbarActions(for editor: DocumentEditor) -> [ToolbarAction] {
        func action(_ editorAction: DocumentEditorAction) -> () -> Void {
            { [weak self] in self?.on(.applyEditorAction(editorAction)) }
        }

        return [
            ToolbarAction(
                id: "heading",
                kind: .headingMenu(
                    headingKeys.enumerated().map { level, key in
                        ToolbarAction.HeadingOption(
                            id: level + 1,
                            title: .localized(key),
                            action: action(.format(.heading(level + 1)))
                        )
                    }),
                isActive: editor.isActive(.format(.heading(1))),
                keyboardShortcut: nil,
                action: {}
            ),
            ToolbarAction(
                id: "bold", kind: .button(systemImage: "bold"),
                isActive: editor.isActive(.format(.bold)), keyboardShortcut: .init("b"),
                action: action(.format(.bold))),
            ToolbarAction(
                id: "italic", kind: .button(systemImage: "italic"),
                isActive: editor.isActive(.format(.italic)), keyboardShortcut: .init("i"),
                action: action(.format(.italic))),
            ToolbarAction(
                id: "strikethrough", kind: .button(systemImage: "strikethrough"),
                isActive: editor.isActive(.format(.strikethrough)), keyboardShortcut: .init("s"),
                action: action(.format(.strikethrough))),
            ToolbarAction(
                id: "inlineCode",
                kind: .button(systemImage: "chevron.left.forwardslash.chevron.right"),
                isActive: editor.isActive(.format(.inlineCode)), keyboardShortcut: .init("e"),
                action: action(.format(.inlineCode))),
            ToolbarAction(
                id: "codeBlock", kind: .button(systemImage: "curlybraces"),
                isActive: editor.isActive(.format(.codeBlock)),
                action: action(.format(.codeBlock))),
            ToolbarAction(
                id: "list", kind: .button(systemImage: "list.bullet"),
                isActive: editor.isActive(.format(.list)), keyboardShortcut: .init("l"),
                action: action(.format(.list))),
            ToolbarAction(
                id: "todoList", kind: .button(systemImage: "checklist"),
                isActive: editor.isActive(.format(.todoList)),
                action: action(.format(.todoList))),
            ToolbarAction(
                id: "dedent", kind: .button(systemImage: "decrease.indent"),
                isActive: editor.isActive(.dedent), keyboardShortcut: .init("\t", shift: true),
                action: action(.dedent)),
        ]
    }

    private func makeMenuActions(for editor: DocumentEditor) -> [ToolbarAction] {
        func action(_ editorAction: DocumentEditorAction) -> () -> Void {
            { [weak self] in self?.on(.applyEditorAction(editorAction)) }
        }
        return [
            ToolbarAction(
                id: "formatDocument", kind: .button(systemImage: "text.alignleft"),
                isActive: editor.isActive(.formatDocument), keyboardShortcut: nil,
                localizedTitle: "note.menu.format", action: action(.formatDocument))
        ]
    }

    private func subscribeToSyncEvents(_ publisher: SyncEventPublisher, folder: Folder) {
        syncSubscription = publisher.subscribe { [weak self] event in
            guard let self else { return }
            switch event {
            case .didPull(let eventFolder), .didMerge(let eventFolder):
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
