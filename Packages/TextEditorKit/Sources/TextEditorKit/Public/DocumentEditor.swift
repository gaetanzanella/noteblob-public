import Foundation

// MARK: - DocumentEditor

@MainActor
public final class DocumentEditor {

    // MARK: - Public Properties

    public weak var delegate: DocumentEditorDelegate?

    // MARK: - Private Properties

    private enum State {
        case empty
        case loaded(url: URL?, originalText: String)
    }

    private struct PendingChange {
        let previousText: String
        let range: NSRange
        let replacementString: String
    }

    private var state: State = .empty
    private weak var textInput: (any TextInput)?
    private var inputAdapter: InputAdapter?
    private let interceptors: [any TypeInterceptor]
    private let lifecycleInterceptors: [any DocumentEditorLifecycleInterceptor]
    private let actionHandlerFactory: any ActionHandlerFactory
    private let documentLayout: any DocumentLayoutInvalidating
    private var pendingChange: PendingChange?

    // MARK: - Init (Public)

    public init() {
        let autoSave = AutoSaveObserver()
        let undoObserver = UndoObserver()
        self.interceptors = [
            ListContinuationInterceptor(),
            ListIndentInterceptor(),
            URLLinkInterceptor(),
            BracketWrapInterceptor(opening: "(", closing: ")"),
            BracketWrapInterceptor(opening: "[", closing: "]"),
            BracketWrapInterceptor(opening: "{", closing: "}"),
            BracketWrapInterceptor(opening: "\"", closing: "\""),
            BracketWrapInterceptor(opening: "`", closing: "`"),
        ]
        self.lifecycleInterceptors = [undoObserver, autoSave]
        let factory = DefaultActionHandlerFactory(undoObserver: undoObserver)
        self.actionHandlerFactory = factory
        self.documentLayout = MarkdownDocumentLayout()
        factory.editor = self
    }

    // MARK: - Init (Internal, for testing)

    init(
        interceptors: [any TypeInterceptor] = [],
        lifecycleInterceptors: [any DocumentEditorLifecycleInterceptor] = [],
        actionHandlerFactory: any ActionHandlerFactory
    ) {
        self.interceptors = interceptors
        self.lifecycleInterceptors = lifecycleInterceptors
        self.actionHandlerFactory = actionHandlerFactory
        self.documentLayout = MarkdownDocumentLayout()
    }

    // MARK: - Document

    public func load(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        state = .loaded(url: url, originalText: content)
        documentLayout.setText(content)
        textInput?.setText(content)
        runLifecycleInterceptors(event: .didLoad)
    }

    func loadText(_ text: String) {
        state = .loaded(url: nil, originalText: text)
        documentLayout.setText(text)
        textInput?.setText(text)
        runLifecycleInterceptors(event: .didLoad)
    }

    public func save() {
        runLifecycleInterceptors(event: .didSave)
    }

    public func cancelEditing() {
        guard case .loaded(_, let originalText) = state else { return }
        guard let textInput else { return }
        textInput.setText(originalText)
        documentLayout.setText(originalText)
        runLifecycleInterceptors(event: .didCancelEditing)
        delegate?.documentEditorDidUpdateActions(self)
    }

    // MARK: - View Binding

    public func attach(to textInput: some TextInput) {
        let adapter = InputAdapter(editor: self)
        textInput.delegate = adapter
        self.inputAdapter = adapter
        self.textInput = textInput

        if case .loaded(_, let originalText) = state {
            textInput.setText(originalText)
            runLifecycleInterceptors(event: .didLoad)
        }
    }

    // MARK: - Actions

    public func apply(_ action: DocumentEditorAction) {
        guard isEnabled(action) else { return }
        guard let context = makeEditorContext() else { return }

        let handler = actionHandlerFactory.makeHandler(for: action)
        let edit =
            handler.isActive(in: context)
            ? handler.deactivate(in: context)
            : handler.activate(in: context)

        guard let edit else { return }
        applyEdit(edit)
        runLifecycleInterceptors(event: .didChangeText)
        delegate?.documentEditorDidUpdateActions(self)
    }

    public func isActive(_ action: DocumentEditorAction) -> Bool {
        guard let context = makeEditorContext() else { return false }
        return actionHandlerFactory.makeHandler(for: action).isActive(in: context)
    }

    /// Disabling matrix — which actions are enabled for which block-level token
    /// at the selection. Columns are the `MarkdownLineToken` case at every line
    /// touched by the selection. `✓` enabled, `✗` disabled.
    ///
    /// Most formatting actions also require the selection to stay on a single
    /// line: inline marks can't span a paragraph break in markdown, and
    /// heading/codeBlock only operate on the cursor's current line. The list
    /// actions (`list`, `todoList`) are the exception — they iterate each
    /// selected line, adding the prefix to any line that isn't already a
    /// matching list item (and stripping the prefix when toggling off).
    ///
    /// | Action                  | paragraph | heading | codeBlock | listItem | blockQuote | thematicBreak | table | htmlBlock |
    /// |-------------------------|-----------|---------|-----------|----------|------------|---------------|-------|-----------|
    /// | bold / italic / strike  | ✓         | ✓       | ✗         | ✓        | ✓          | ✗             | ✗     | ✗         |
    /// | inlineCode              | ✓         | ✓       | ✗         | ✓        | ✓          | ✗             | ✗     | ✗         |
    /// | heading(n)              | ✓         | ✓       | ✗         | ✗        | ✗          | ✗             | ✗     | ✗         |
    /// | codeBlock               | ✓         | ✗       | ✓         | ✗        | ✗          | ✗             | ✗     | ✗         |
    /// | list / todoList         | ✓         | ✗       | ✗         | ✓        | ✓          | ✗             | ✗     | ✗         |
    /// | indent / dedent         | gated to list items only (dedent also requires depth > 0)                                     |
    /// | formatDocument          | ✓ everywhere                                                                                  |
    /// | undo / redo             | depends only on `undoObserver.canUndo` / `canRedo`                                            |
    public func isEnabled(_ action: DocumentEditorAction) -> Bool {
        guard isVisible(action) else { return false }
        guard let context = makeEditorContext() else { return false }
        return actionHandlerFactory.makeHandler(for: action).isEnabled(in: context)
    }

    public func isVisible(_ action: DocumentEditorAction) -> Bool {
        guard let context = makeEditorContext() else { return false }
        return actionHandlerFactory.makeHandler(for: action).isVisible(in: context)
    }

    // MARK: - Text Change Handling

    func willChangeText(in range: NSRange, replacementString: String) {
        guard let textInput else { return }
        pendingChange = PendingChange(
            previousText: textInput.text(),
            range: range,
            replacementString: replacementString
        )
    }

    func didChangeText() {
        guard let change = pendingChange else { return }
        pendingChange = nil
        guard let textInput else { return }

        let newText = textInput.text()
        let utf16Range = change.range.location..<(change.range.location + change.range.length)

        documentLayout.update(
            newText: newText,
            changedRange: utf16Range,
            replacementLength: change.replacementString.utf16.count
        )

        if let editorContext = makeEditorContext() {
            let typeContext = TypeContext(
                previousText: change.previousText,
                newText: newText,
                changedRange: utf16Range,
                replacementString: change.replacementString,
                editorContext: editorContext
            )
            for interceptor in interceptors.sorted(by: { $0.priority < $1.priority }) {
                if let edit = interceptor.intercept(typeContext) {
                    applyEdit(edit)
                    break
                }
            }
        }
        runLifecycleInterceptors(event: .didChangeText)
        delegate?.documentEditorDidUpdateActions(self)
    }

    func didChangeSelection() {
        runLifecycleInterceptors(event: .didChangeSelection)
        delegate?.documentEditorDidUpdateActions(self)
    }

    // MARK: - Private

    private func runLifecycleInterceptors(event: LifecycleContext.Event) {
        guard let context = makeEditorContext() else { return }
        let lifecycleContext = LifecycleContext(
            event: event,
            editorContext: context
        )
        for interceptor in lifecycleInterceptors {
            interceptor.intercept(lifecycleContext)
        }
    }

    private func makeEditorContext() -> EditorContext? {
        guard let textInput else { return nil }
        let nsRange = textInput.selectedRange()
        let url: URL? = if case .loaded(let url, _) = state { url } else { nil }
        return EditorContext(
            selectionUTF16: nsRange.location..<(nsRange.location + nsRange.length),
            text: textInput.text(),
            documentLayout: documentLayout,
            documentURL: url
        )
    }

    private func applyEdit(_ edit: TextEdit) {
        guard let textInput else { return }

        for change in edit.changes.sortedDescending() {
            let range: Range<Int>
            let replacement: String

            switch change {
            case .insert(let at, let string):
                range = at..<at
                replacement = string
            case .replace(let r, let with):
                range = r
                replacement = with
            case .delete(let r):
                range = r
                replacement = ""
            }

            if textInput.text().isEmpty {
                textInput.setText(replacement)
            } else {
                textInput.replaceCharacters(
                    in: NSRange(location: range.lowerBound, length: range.count),
                    with: replacement
                )
            }
            documentLayout.update(
                newText: textInput.text(),
                changedRange: range,
                replacementLength: replacement.utf16.count
            )
        }

        textInput.setSelectedRange(
            NSRange(location: edit.selection.lowerBound, length: edit.selection.count))
    }
}

// MARK: - DefaultActionHandlerFactory

@MainActor
final class DefaultActionHandlerFactory: ActionHandlerFactory {

    let undoObserver: UndoObserver
    weak var editor: DocumentEditor?

    init(undoObserver: UndoObserver) {
        self.undoObserver = undoObserver
    }

    func makeHandler(for action: DocumentEditorAction) -> DocumentEditorActionHandler {
        switch action {
        case .format(let mark):
            switch mark {
            case .bold, .italic, .strikethrough, .inlineCode:
                return WrapActionHandler(mark: mark)
            case .heading(let level):
                return HeadingActionHandler(level: level)
            case .codeBlock:
                return CodeBlockActionHandler()
            case .list:
                return ListActionHandler(todo: false)
            case .todoList:
                return ListActionHandler(todo: true)
            }
        case .indent:
            return IndentActionHandler(direction: .indent)
        case .dedent:
            return IndentActionHandler(direction: .dedent)
        case .formatDocument:
            return FormatActionHandler()
        case .insert(let insertion):
            switch insertion {
            case .link(let target, let title):
                return LinkActionHandler(target: target, fallbackTitle: title)
            case .table(let table):
                return TableActionHandler(table: table)
            }
        case .editTable:
            return EditTableActionHandler(onRequest: { [weak editor] request in
                guard let editor else { return }
                editor.delegate?.documentEditor(editor, requestTableEditing: request)
            })
        case .undo:
            return UndoActionHandler(undoObserver: undoObserver)
        case .redo:
            return RedoActionHandler(undoObserver: undoObserver)
        }
    }
}
