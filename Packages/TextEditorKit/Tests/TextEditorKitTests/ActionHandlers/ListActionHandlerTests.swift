import Testing
@testable import TextEditorKit

@Suite
struct ListActionHandlerTests {

    // MARK: - isActive

    @Test @MainActor
    func isActiveOnListItem() {
        let ctx = makeContext("- Hello", cursor: 2)
        let handler = ListActionHandler(todo: false)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnTodoWhenPlainList() {
        let ctx = makeContext("- Hello", cursor: 2)
        let handler = ListActionHandler(todo: true)
        #expect(!handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveOnTodoItem() {
        let ctx = makeContext("- [ ] Task", cursor: 6)
        let handler = ListActionHandler(todo: true)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = ListActionHandler(todo: false)
        #expect(!handler.isActive(in: ctx))
    }

    // MARK: - activate

    @Test @MainActor
    func activateInsertsDash() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = ListActionHandler(todo: false)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 0, string: "- ")])
        // Single-line: the user's cursor is preserved, just shifted past
        // the inserted prefix.
        #expect(edit!.selection == 2..<2)
    }

    @Test @MainActor
    func activateInsertsTodoPrefix() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = ListActionHandler(todo: true)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 0, string: "- [ ] ")])
        #expect(edit!.selection == 6..<6)
    }

    @Test @MainActor
    func activateOnEmptyDocumentInsertsDash() throws {
        let ctx = makeContext("", cursor: 0)
        let edit = try #require(ListActionHandler(todo: false).activate(in: ctx))
        let result = applyEdit(edit, to: "")
        #expect(result == "- ")
    }

    @Test @MainActor
    func activateOnEmptyDocumentInsertsTodoPrefix() throws {
        let ctx = makeContext("", cursor: 0)
        let edit = try #require(ListActionHandler(todo: true).activate(in: ctx))
        let result = applyEdit(edit, to: "")
        #expect(result == "- [ ] ")
    }

    @Test @MainActor
    func activateReplacesExistingListWithTodo() {
        let ctx = makeContext("- Hello", cursor: 2)
        let handler = ListActionHandler(todo: true)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 0..<2, with: "- [ ] ")])
        // Cursor was at the content boundary (after "- "); after replace
        // it stays at the new boundary (after "- [ ] ").
        #expect(edit!.selection == 6..<6)
    }

    // MARK: - deactivate

    @Test @MainActor
    func deactivateRemovesListPrefix() {
        let ctx = makeContext("- Hello", cursor: 4)
        let handler = ListActionHandler(todo: false)
        let edit = handler.deactivate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<2)])
        // Single-line: cursor preserved, shifted left by the deleted prefix.
        #expect(edit!.selection == 2..<2)
    }

    @Test @MainActor
    func deactivateRemovesTodoPrefx() {
        let ctx = makeContext("- [ ] Task", cursor: 8)
        let handler = ListActionHandler(todo: true)
        let edit = handler.deactivate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<6)])
        #expect(edit!.selection == 2..<2)
    }

    @Test @MainActor
    func deactivateReturnsNilOnParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = ListActionHandler(todo: false)
        #expect(handler.deactivate(in: ctx) == nil)
    }

    @Test @MainActor
    func deactivateRemovesPrefixFromIndentedListItem() throws {
        let text = "  - Hello"
        let ctx = makeContext(text, cursor: 4)
        let edit = try #require(ListActionHandler(todo: false).deactivate(in: ctx))
        let result = applyEdit(edit, to: text)
        #expect(result == "Hello")
    }

    @Test @MainActor
    func activateConvertsIndentedListItemToTodo() throws {
        let text = "  - Hello"
        let ctx = makeContext(text, cursor: 4)
        let edit = try #require(ListActionHandler(todo: true).activate(in: ctx))
        let result = applyEdit(edit, to: text)
        #expect(result == "  - [ ] Hello")
    }

    // MARK: - isEnabled

    @Test @MainActor
    func isEnabledOnParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        #expect(ListActionHandler(todo: false).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isEnabledOnListItem() {
        let ctx = makeContext("- hello", cursor: 2)
        #expect(ListActionHandler(todo: true).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isEnabledInsideBlockQuote() {
        let ctx = makeContext("> hello", cursor: 2)
        #expect(ListActionHandler(todo: false).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledOnHeading() {
        let ctx = makeContext("# Hello", cursor: 2)
        #expect(!ListActionHandler(todo: false).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledInsideCodeBlock() {
        let ctx = makeContext("```\ncode\n```", cursor: 6)
        #expect(!ListActionHandler(todo: false).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isEnabledOnMultiLineParagraphSelection() {
        // Multi-line selections are allowed as long as every line sits in
        // an allowed block kind — list iterates and prefixes each line.
        let ctx = makeContext("alpha\n\nbeta", cursor: 0, cursorEnd: 11)
        #expect(ListActionHandler(todo: false).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledOnMultiLineSelectionCrossingCodeBlock() {
        // A line inside a code block disqualifies list.
        let ctx = makeContext("alpha\n\n```\ncode\n```", cursor: 0, cursorEnd: 19)
        #expect(!ListActionHandler(todo: false).isEnabled(in: ctx))
    }

    @Test @MainActor
    func activateAddsPrefixToEachNonListLine() throws {
        // "alpha\n\nbeta" — lines 0 and 2 are paragraphs, line 1 is blank.
        // Activate should prefix each paragraph line and skip the blank.
        let ctx = makeContext("alpha\n\nbeta", cursor: 0, cursorEnd: 11)
        let edit = try #require(ListActionHandler(todo: false).activate(in: ctx))
        let result = applyEdit(edit, to: "alpha\n\nbeta")
        #expect(result == "- alpha\n\n- beta")
    }

    @Test @MainActor
    func activateSkipsLinesThatAreAlreadyMatchingListItems() throws {
        // Mixed: line 0 paragraph, line 1 already "- item", line 2 paragraph.
        let text = "alpha\n- item\nbeta"
        let ctx = makeContext(text, cursor: 0, cursorEnd: text.utf16.count)
        let edit = try #require(ListActionHandler(todo: false).activate(in: ctx))
        let result = applyEdit(edit, to: text)
        #expect(result == "- alpha\n- item\n- beta")
    }

    @Test @MainActor
    func deactivateRemovesPrefixFromEachListLine() throws {
        let text = "- alpha\n- beta"
        let ctx = makeContext(text, cursor: 0, cursorEnd: text.utf16.count)
        let edit = try #require(ListActionHandler(todo: false).deactivate(in: ctx))
        let result = applyEdit(edit, to: text)
        #expect(result == "alpha\nbeta")
    }

    @Test @MainActor
    func isActiveOnlyWhenAllLinesAreMatchingListItems() {
        let allBullets = makeContext("- alpha\n- beta", cursor: 0, cursorEnd: 14)
        #expect(ListActionHandler(todo: false).isActive(in: allBullets))

        let mixed = makeContext("- alpha\nbeta", cursor: 0, cursorEnd: 12)
        #expect(!ListActionHandler(todo: false).isActive(in: mixed))
    }
}
