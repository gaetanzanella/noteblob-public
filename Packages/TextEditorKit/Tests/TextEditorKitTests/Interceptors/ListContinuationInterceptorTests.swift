import Testing

@testable import TextEditorKit

@Suite
struct ListContinuationInterceptorTests {

    private let interceptor = ListContinuationInterceptor()

    // MARK: - Continuation

    @Test @MainActor
    func continuesUnorderedList() {
        let ctx = makeNewlineContext(textBefore: "- Hello")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 8, string: "- ")])
        #expect(edit!.selection == 10..<10)
    }

    @Test @MainActor
    func continuesOrderedList() {
        let ctx = makeNewlineContext(textBefore: "1. First")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 9, string: "2. ")])
        #expect(edit!.selection == 12..<12)
    }

    @Test @MainActor
    func continuesTodo() {
        let ctx = makeNewlineContext(textBefore: "- [ ] Task")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 11, string: "- [ ] ")])
        #expect(edit!.selection == 17..<17)
    }

    // MARK: - Termination (empty list item)

    @Test @MainActor
    func removesEmptyListItem() {
        // "- " + newline → "- \n", cursor on line 1
        let ctx = makeNewlineContext(textBefore: "- ")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<3)])
        #expect(edit!.selection == 0..<0)
    }

    @Test @MainActor
    func removesEmptyTodoItem() {
        let ctx = makeNewlineContext(textBefore: "- [ ] ")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<7)])
        #expect(edit!.selection == 0..<0)
    }

    @Test @MainActor
    func removesListItemWithOnlyWhitespace() {
        // "- " + some spaces + newline → should remove like empty
        let ctx = makeNewlineContext(textBefore: "-    ")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<6)])
        #expect(edit!.selection == 0..<0)
    }

    // MARK: - Next line is already a list item

    @Test @MainActor
    func doesNotContinueWhenNextLineIsListItem() {
        // Enter between two list items: "- First\n\n- Second"
        // cursor on blank line 1
        let ctx = makeNewlineContext(textBefore: "- First", textAfter: "- Second")
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func doesNotContinueWhenNextLineIsTodo() {
        let ctx = makeNewlineContext(textBefore: "- [ ] Task1", textAfter: "- [ ] Task2")
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func continuesWhenNextLineIsParagraph() {
        let ctx = makeNewlineContext(textBefore: "- Hello", textAfter: "World")
        let edit = interceptor.intercept(ctx)
        #expect(edit != nil)
    }

    // MARK: - No-op

    @Test @MainActor
    func ignoresNonNewline() {
        let ctx = makeTypeContext(
            text: "- Hello",
            cursor: 7,
            replacement: "x"
        )
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func ignoresNewlineOnParagraph() {
        let ctx = makeNewlineContext(textBefore: "Hello")
        #expect(interceptor.intercept(ctx) == nil)
    }

    // MARK: - Helpers

    /// Simulates state AFTER UIKit inserted the newline.
    /// Text = textBefore + "\n" + (textAfter ?? ""), cursor at start of new line.
    @MainActor
    private func makeNewlineContext(textBefore: String, textAfter: String? = nil) -> TypeContext {
        let previousText = textBefore + (textAfter.map { "\n" + $0 } ?? "")
        var newText = textBefore + "\n"
        let cursorOffset = newText.utf16.count
        if let textAfter {
            newText += textAfter
        }
        return makeTypeContextFromNewText(
            previousText: previousText,
            newText: newText,
            changedRange: textBefore.utf16.count..<textBefore.utf16.count,
            cursor: cursorOffset,
            replacement: "\n"
        )
    }

    @MainActor
    private func makeTypeContext(text: String, cursor: Int, replacement: String) -> TypeContext {
        makeTypeContextFromNewText(
            previousText: text,
            newText: text,
            changedRange: cursor..<cursor,
            cursor: cursor,
            replacement: replacement
        )
    }

    @MainActor
    private func makeTypeContextFromNewText(
        previousText: String,
        newText: String,
        changedRange: Range<Int>,
        cursor: Int,
        replacement: String
    ) -> TypeContext {
        let storage = MarkdownDocumentLayout()
        storage.setText(newText)
        let editorContext = EditorContext(
            selectionUTF16: cursor..<cursor,
            text: newText,
            documentLayout: storage
        )
        return TypeContext(
            previousText: previousText,
            newText: newText,
            changedRange: changedRange,
            replacementString: replacement,
            editorContext: editorContext
        )
    }
}
