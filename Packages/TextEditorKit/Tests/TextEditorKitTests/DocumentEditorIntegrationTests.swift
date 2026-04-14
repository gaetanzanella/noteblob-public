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
        let t1 = te.input._text
        te.input.simulateChange(range: NSRange(location: 17, length: 2), replacement: "", newText: "- First\n- Second\n")
        let t2 = te.input._text
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

    // MARK: - Cancel

    @Test @MainActor
    func cancelRevertsTextAndFile() throws {
        let te = makeEditor("- Hello")

        te.input.simulateChange(range: NSRange(location: 7, length: 0), replacement: " World", newText: "- Hello World")

        te.editor.cancelEditing()
        #expect(te.input._text == "- Hello")

        #expect(try te.fileContent() == "- Hello")
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

