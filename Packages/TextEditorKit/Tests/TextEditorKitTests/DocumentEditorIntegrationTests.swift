import Foundation
import Testing
import TextEditorKit

@Suite
struct DocumentEditorIntegrationTests {

    private let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("TextEditorKitTests")

    // MARK: - List Continuation

    @Test @MainActor
    func enterOnListItemCreatesContinuation() {
        let te = makeEditor("- Hello")

        te.input.simulateChange(range: NSRange(location: 7, length: 0), replacement: "\n", newText: "- Hello\n")

        #expect(te.input._text == "- Hello\n- ")
    }

    @Test @MainActor
    func enterAfterDeletingBackToSecondListItem() {
        let te = makeEditor("- First\n- Second")

        // Enter
        te.input.simulateChange(range: NSRange(location: 16, length: 0), replacement: "\n", newText: "- First\n- Second\n")
        #expect(te.input._text == "- First\n- Second\n- ")

        // Delete "- ", then "\n"
        te.input.simulateChange(range: NSRange(location: 17, length: 2), replacement: "", newText: "- First\n- Second\n")
        te.input.simulateChange(range: NSRange(location: 16, length: 1), replacement: "", newText: "- First\n- Second")

        // Enter again
        te.input.simulateChange(range: NSRange(location: 16, length: 0), replacement: "\n", newText: "- First\n- Second\n")
        #expect(te.input._text == "- First\n- Second\n- ")
    }

    // MARK: - Multi-block Document

    @Test @MainActor
    func multiBlockEnterCycle() {
        let te = makeEditor("# Title\n\nParagraph\n\n- Hello")

        te.input._selectedRange = NSRange(location: 26, length: 0)
        #expect(te.editor.isActive(.format(.list)))

        // Enter
        te.input.simulateChange(range: NSRange(location: 27, length: 0), replacement: "\n", newText: "# Title\n\nParagraph\n\n- Hello\n")
        #expect(te.input._text == "# Title\n\nParagraph\n\n- Hello\n- ")

        // Delete and enter again
        let before = te.input._text
        te.input.simulateChange(range: NSRange(location: 27, length: before.utf16.count - 27), replacement: "", newText: "# Title\n\nParagraph\n\n- Hello")

        te.input.simulateChange(range: NSRange(location: 27, length: 0), replacement: "\n", newText: "# Title\n\nParagraph\n\n- Hello\n")
        #expect(te.input._text == "# Title\n\nParagraph\n\n- Hello\n- ")
    }

    // MARK: - Action State

    @Test @MainActor
    func isActiveCorrectAfterTyping() {
        let te = makeEditor("- Hello")

        te.input.simulateChange(range: NSRange(location: 7, length: 0), replacement: "!", newText: "- Hello!")

        #expect(te.editor.isActive(.format(.list)))
    }

    @Test @MainActor
    func isActiveCorrectAfterDeletingLine() {
        let te = makeEditor("- Hello\n- ")

        te.input.simulateChange(range: NSRange(location: 7, length: 3), replacement: "", newText: "- Hello")

        #expect(te.editor.isActive(.format(.list)))
    }

    // MARK: - Format Action

    @Test @MainActor
    func formatDocumentUpdatesText() {
        let te = makeEditor("- [x] Done\n- [ ] Todo")

        te.editor.apply(.formatDocument)

        #expect(te.input._text == "- [ ] Todo\n- [x] Done")
    }

    @Test @MainActor
    func savePersistsToDisk() throws {
        let te = makeEditor("- [x] Done\n- [ ] Todo")

        te.editor.apply(.formatDocument)
        te.editor.save()

        #expect(try te.fileContent() == "- [ ] Todo\n- [x] Done")
    }

    // MARK: - Bold toggle on list item

    @Test @MainActor
    func toggleBoldOnListItem() {
        let te = makeEditor("- hello world")

        // Select "world"
        te.input._selectedRange = NSRange(location: 8, length: 5)

        // First bold → wraps
        te.editor.apply(.format(.bold))
        #expect(te.input._text == "- hello **world**")

        // Second bold → should unwrap
        te.editor.apply(.format(.bold))
        #expect(te.input._text == "- hello world")
    }

    @Test @MainActor
    func toggleBoldOnComplexListItem() {
        let text = """
        # WatchOS

        - Depuis wOS 6, les apps peuvent (hello)
        - Avant wOS 6, les apps étaient dépendantes ( app iOS, tout se passait par le framework Watch Connectivity
        - Y\u{2019}a une target (extension) qui contient le code, une autre
        - wOS 6+: \\_[WKExtendedRuntimeSession](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession)\\_\\_ (\\_comme background mode mais étendu mais avec des contraintes dans le temps)$
        """
        let te = makeEditor(text)

        let codeStart = (text as NSString).range(of: "le code").location + 3
        te.input._selectedRange = NSRange(location: codeStart, length: 4)

        te.editor.apply(.format(.bold))
        #expect(te.input._text.contains("le **code**,"))

        te.editor.apply(.format(.bold))
        #expect(te.input._text == text)
    }

    // MARK: - Empty-text attribute preservation

    @Test @MainActor
    func applyEditOnEmptyTextUsesSetTextInsteadOfReplaceCharacters() {
        // When the text input is empty, `NSTextStorage.replaceCharacters`
        // leaves the inserted text without any attributes (no surrounding
        // run to inherit from) — which surfaces on UITextView as the
        // wrong font and a default color that's invisible in dark mode.
        // `applyEdit` must route through the plain-text `setText` in
        // that case so the view re-establishes its defaults.
        let te = makeEditor("")
        #expect(te.input._text == "")
        let replaceCallsBefore = te.input.replaceCharactersCallCount

        te.editor.apply(.format(.heading(2)))

        #expect(te.input._text == "## ")
        #expect(te.input.replaceCharactersCallCount == replaceCallsBefore)
        #expect(te.input.setTextCallCount >= 1)
    }

    @Test @MainActor
    func applyEditOnNonEmptyTextUsesReplaceCharacters() {
        // The empty-text branch must not affect the normal path: when the
        // store has content, `replaceCharacters` inherits attributes from
        // neighboring characters and we keep the minimal-diff benefits.
        let te = makeEditor("hello")
        let setTextCallsBefore = te.input.setTextCallCount
        let replaceCallsBefore = te.input.replaceCharactersCallCount

        te.editor.apply(.format(.heading(2)))

        #expect(te.input._text == "## hello")
        #expect(te.input.setTextCallCount == setTextCallsBefore)
        #expect(te.input.replaceCharactersCallCount > replaceCallsBefore)
    }

    // MARK: - Undo / Redo

    @Test @MainActor
    func undoAndRedoRoundTripThroughEditor() {
        // End-to-end smoke test: a user edit is observed by UndoObserver,
        // editor.apply(.undo) reverts the textInput, and editor.apply(.redo)
        // re-applies it. The unit tests cover the semantics; this one
        // proves the wiring (InputAdapter → lifecycle interceptors →
        // action handlers → applyEdit → textInput) is connected.
        let te = makeEditor("hello")

        te.input.simulateChange(
            range: NSRange(location: 5, length: 0),
            replacement: "!",
            newText: "hello!"
        )
        #expect(te.input._text == "hello!")

        te.editor.apply(.undo)
        #expect(te.input._text == "hello")

        te.editor.apply(.redo)
        #expect(te.input._text == "hello!")
    }

    // MARK: - Cancel

    @Test @MainActor
    func cancelRevertsTextAndFile() throws {
        let te = makeEditor("- Hello")

        te.input.simulateChange(range: NSRange(location: 7, length: 0), replacement: " World", newText: "- Hello World")

        te.editor.cancelEditing()
        #expect(te.input._text == "- Hello")

        #expect(try te.fileContent() == "- Hello")
    }

    // MARK: - Edit Table

    /// Smoke test: `apply(.editTable)` must reach the delegate's
    /// `documentEditor(_:requestTableEditing:)` hook with a populated request.
    /// Behavior of the request itself (parsing, selection, etc.) lives in
    /// `EditTableActionHandlerTests`.
    @Test @MainActor
    func editTableActionInvokesDelegate() {
        let te = makeEditor("|h|\n|-|\n|x|\n")
        te.input.setSelectedRange(NSRange(location: 1, length: 0))
        let stub = StubTableEditingDelegate()
        te.editor.delegate = stub

        te.editor.apply(.editTable)

        #expect(stub.received?.currentTable.headers == ["h"])
    }

    /// Inserting a table and then format-document'ing the result must be a
    /// no-op: both go through the same `MarkupFormatter.Options.documentDefault`
    /// pipeline, so the table's whitespace shape is already what the formatter
    /// would produce on a fresh parse.
    @Test @MainActor
    func insertTableThenFormatDocumentDoesNotModifyTable() {
        let te = makeEditor("")
        let table = MarkdownTable(headers: ["Name", "Score"], rows: [["Alice", "10"], ["Bob", "20"]])

        te.editor.apply(.insert(.table(table)))
        let afterInsert = te.input._text

        te.editor.apply(.formatDocument)
        let afterFormat = te.input._text

        #expect(afterInsert == afterFormat)
    }

    // MARK: - Private

    private struct TestEditor {
        let editor: DocumentEditor
        let input: MockTextInput
        let url: URL

        func fileContent() throws -> String {
            try String(contentsOf: url, encoding: .utf8)
        }
    }

    @MainActor
    private func makeEditor(_ text: String) -> TestEditor {
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let url = tmpDir.appendingPathComponent(UUID().uuidString + ".md")
        try! text.write(to: url, atomically: true, encoding: .utf8)

        let editor = DocumentEditor()
        let input = MockTextInput()
        editor.attach(to: input)
        try! editor.load(from: url)
        return TestEditor(editor: editor, input: input, url: url)
    }

}

@MainActor
private final class StubTableEditingDelegate: DocumentEditorDelegate {
    var received: TableEditingRequest?

    func documentEditorDidUpdateActions(_ editor: DocumentEditor) {}

    func documentEditor(
        _ editor: DocumentEditor,
        requestTableEditing request: TableEditingRequest
    ) {
        received = request
    }
}

