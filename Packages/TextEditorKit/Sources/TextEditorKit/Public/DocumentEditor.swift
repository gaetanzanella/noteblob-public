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
        self.interceptors = [
            ListContinuationInterceptor(),
            ListIndentInterceptor(),
        ]
        self.lifecycleInterceptors = [autoSave]
        self.actionHandlerFactory = DefaultActionHandlerFactory()
        self.documentLayout = MarkdownDocumentLayout()
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
    }

    func loadText(_ text: String) {
        state = .loaded(url: nil, originalText: text)
        documentLayout.setText(text)
        textInput?.setText(text)
    }

    public func save() {
        guard let context = makeEditorContext() else { return }
        runLifecycleInterceptors(LifecycleContext(event: .didSave, editorContext: context))
    }

    public func cancelEditing() {
        guard case .loaded(_, let originalText) = state else { return }
        guard let textInput else { return }
        let previousText = textInput.text()
        textInput.setText(originalText)
        documentLayout.setText(originalText)

        if let editorContext = makeEditorContext() {
            let typeContext = TypeContext(
                previousText: previousText,
                newText: originalText,
                changedRange: 0..<previousText.utf16.count,
                replacementString: originalText,
                editorContext: editorContext
            )
            runInterceptors(typeContext)
            runLifecycleInterceptors(LifecycleContext(event: .didCancelEditing, editorContext: editorContext))
        }
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
        }
    }

    // MARK: - Actions

    public func apply(_ action: DocumentEditorAction) {
        guard isEnabled(action) else { return }
        guard let context = makeEditorContext() else { return }

        let handler = actionHandlerFactory.makeHandler(for: action)
        let edit = handler.isActive(in: context)
            ? handler.deactivate(in: context)
            : handler.activate(in: context)

        if let edit {
            applyEdit(edit)
        }
    }

    public func isActive(_ action: DocumentEditorAction) -> Bool {
        guard let context = makeEditorContext() else { return false }
        return actionHandlerFactory.makeHandler(for: action).isActive(in: context)
    }

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
            runInterceptors(typeContext)
            runLifecycleInterceptors(LifecycleContext(event: .didChangeText, editorContext: editorContext))
        }
        delegate?.documentEditorDidUpdateActions(self)
    }

    func didChangeSelection() {
        delegate?.documentEditorDidUpdateActions(self)
    }

    // MARK: - Private

    private func runLifecycleInterceptors(_ context: LifecycleContext) {
        for interceptor in lifecycleInterceptors {
            interceptor.intercept(context)
        }
    }

    private var currentURL: URL? {
        if case .loaded(let url, _) = state { return url }
        return nil
    }

    private func makeEditorContext() -> EditorContext? {
        guard let textInput else { return nil }
        let nsRange = textInput.selectedRange()
        return EditorContext(
            selectionUTF16: nsRange.location..<(nsRange.location + nsRange.length),
            text: textInput.text(),
            documentLayout: documentLayout,
            documentURL: currentURL
        )
    }

    private func runInterceptors(_ context: TypeContext) {
        let sorted = interceptors.sorted { $0.priority < $1.priority }
        for interceptor in sorted {
            if let edit = interceptor.intercept(context) {
                applyEdit(edit)
                return
            }
        }
    }

    private func applyEdit(_ edit: TextEdit) {
        guard let textInput else { return }

        for change in edit.changes.sortedDescending() {
            let nsRange: NSRange
            let replacement: String

            switch change {
            case .insert(let at, let string):
                nsRange = NSRange(location: at, length: 0)
                replacement = string
            case .replace(let range, let with):
                nsRange = NSRange(location: range.lowerBound, length: range.count)
                replacement = with
            case .delete(let range):
                nsRange = NSRange(location: range.lowerBound, length: range.count)
                replacement = ""
            }

            textInput.replaceCharacters(in: nsRange, with: replacement)
        }

        textInput.setSelectedRange(NSRange(location: edit.selection.lowerBound, length: edit.selection.count))
        documentLayout.setText(textInput.text())
        if let context = makeEditorContext() {
            runLifecycleInterceptors(LifecycleContext(event: .didChangeText, editorContext: context))
        }
        delegate?.documentEditorDidUpdateActions(self)
    }
}

// MARK: - DefaultActionHandlerFactory

struct DefaultActionHandlerFactory: ActionHandlerFactory {

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
        }
    }
}
