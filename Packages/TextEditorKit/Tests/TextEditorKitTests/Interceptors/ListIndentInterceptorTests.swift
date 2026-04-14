import Testing

@testable import TextEditorKit

@Suite
struct ListIndentInterceptorTests {

    private let interceptor = ListIndentInterceptor()

    // MARK: - Indent

    @Test @MainActor
    func indentsListItem() {
        // "- Hello" + Tab → "- Hello\t", cursor at 8
        let ctx = makeTabContext(textBefore: "- Hello")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        // Should delete tab (position 7..<8) and insert 2 spaces at line start (0)
        #expect(edit!.changes == [
            .delete(7..<8),
            .insert(at: 0, string: "  "),
        ])
        // Cursor should be at original position + indent (7 + 2 = 9)
        #expect(edit!.selection == 9..<9)
    }

    @Test @MainActor
    func indentsListItemWithCursorInMiddle() {
        // "- He|llo" → tab inserted at position 4: "- He\tllo", cursor at 5
        let ctx = makeTabContext(textBefore: "- He", textAfter: "llo")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [
            .delete(4..<5),
            .insert(at: 0, string: "  "),
        ])
        #expect(edit!.selection == 6..<6)
    }

    @Test @MainActor
    func indentsTodoItem() {
        let ctx = makeTabContext(textBefore: "- [ ] Task")
        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [
            .delete(10..<11),
            .insert(at: 0, string: "  "),
        ])
        #expect(edit!.selection == 12..<12)
    }

    // MARK: - No-op

    @Test @MainActor
    func ignoresTabOnParagraph() {
        let ctx = makeTabContext(textBefore: "Hello")
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func ignoresNonTab() {
        let ctx = makeTypeContext(text: "- Hello", cursor: 7, replacement: "x")
        #expect(interceptor.intercept(ctx) == nil)
    }

    // MARK: - Helpers

    /// Simulates state AFTER the text view inserted the tab character.
    /// Text = textBefore + "\t" + (textAfter ?? ""), cursor right after the tab.
    @MainActor
    private func makeTabContext(textBefore: String, textAfter: String? = nil) -> TypeContext {
        let previousText = textBefore + (textAfter ?? "")
        var newText = textBefore + "\t"
        let cursorOffset = newText.utf16.count
        if let textAfter {
            newText += textAfter
        }
        return makeTypeContextFromNewText(
            previousText: previousText,
            newText: newText,
            changedRange: textBefore.utf16.count..<textBefore.utf16.count,
            cursor: cursorOffset,
            replacement: "\t"
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
