import Testing

@testable import TextEditorKit

@Suite
struct BracketWrapInterceptorTests {

    private let parens = BracketWrapInterceptor(opening: "(", closing: ")")

    // MARK: - Wrapping

    @Test @MainActor
    func wrapsSelection() {
        // Selected "world" in "hello world" (range 6..<11), user types "("
        // After UIKit replacement: "hello (" (cursor at 7)
        let ctx = makeReplacementContext(
            previousText: "hello world",
            newText: "hello (",
            selectedRange: 6..<11,
            replacement: "("
        )
        let edit = parens.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 7, string: "world)")])
        #expect(edit!.selection == 7..<12)
    }

    @Test @MainActor
    func wrapsSelectionAtStart() {
        let ctx = makeReplacementContext(
            previousText: "hello world",
            newText: "( world",
            selectedRange: 0..<5,
            replacement: "("
        )
        let edit = parens.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 1, string: "hello)")])
        #expect(edit!.selection == 1..<6)
    }

    @Test @MainActor
    func wrapsMultibyteSelection() {
        // Emoji uses two UTF-16 code units
        let ctx = makeReplacementContext(
            previousText: "say 🙂",
            newText: "say (",
            selectedRange: 4..<6,
            replacement: "("
        )
        let edit = parens.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 5, string: "🙂)")])
        #expect(edit!.selection == 5..<7)
    }

    @Test @MainActor
    func wrapsWithCustomPair() {
        let quote = BracketWrapInterceptor(opening: "\"", closing: "\"")
        let ctx = makeReplacementContext(
            previousText: "say hi",
            newText: "say \"",
            selectedRange: 4..<6,
            replacement: "\""
        )
        let edit = quote.intercept(ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 5, string: "hi\"")])
        #expect(edit!.selection == 5..<7)
    }

    // MARK: - No-op

    @Test @MainActor
    func ignoresWhenNoSelection() {
        let ctx = makeReplacementContext(
            previousText: "hello",
            newText: "hello(",
            selectedRange: 5..<5,
            replacement: "("
        )
        #expect(parens.intercept(ctx) == nil)
    }

    @Test @MainActor
    func ignoresWhenReplacementDoesNotMatchOpening() {
        let ctx = makeReplacementContext(
            previousText: "hello world",
            newText: "hello [",
            selectedRange: 6..<11,
            replacement: "["
        )
        #expect(parens.intercept(ctx) == nil)
    }

    @Test @MainActor
    func ignoresClosingCharacter() {
        let ctx = makeReplacementContext(
            previousText: "hello world",
            newText: "hello )",
            selectedRange: 6..<11,
            replacement: ")"
        )
        #expect(parens.intercept(ctx) == nil)
    }

    @Test @MainActor
    func ignoresMultiCharReplacement() {
        let ctx = makeReplacementContext(
            previousText: "hello world",
            newText: "hello (abc",
            selectedRange: 6..<11,
            replacement: "(abc"
        )
        #expect(parens.intercept(ctx) == nil)
    }

    // MARK: - Helpers

    /// Simulates state AFTER UIKit replaced `selectedRange` in `previousText` with `replacement`.
    @MainActor
    private func makeReplacementContext(
        previousText: String,
        newText: String,
        selectedRange: Range<Int>,
        replacement: String
    ) -> TypeContext {
        let storage = MarkdownDocumentLayout()
        storage.setText(newText)
        let cursor = selectedRange.lowerBound + replacement.utf16.count
        let editorContext = EditorContext(
            selectionUTF16: cursor..<cursor,
            text: newText,
            documentLayout: storage
        )
        return TypeContext(
            previousText: previousText,
            newText: newText,
            changedRange: selectedRange,
            replacementString: replacement,
            editorContext: editorContext
        )
    }
}
