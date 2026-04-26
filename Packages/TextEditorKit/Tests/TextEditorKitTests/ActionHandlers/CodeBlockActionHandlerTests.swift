import Testing
@testable import TextEditorKit

@Suite
struct CodeBlockActionHandlerTests {

    // MARK: - isActive

    @Test @MainActor
    func isActiveInsideCodeBlock() {
        let text = "```\nhello\n```"
        let ctx = makeContext(text, cursor: 5) // inside "hello"
        let handler = CodeBlockActionHandler()
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnParagraph() {
        let ctx = makeContext("Hello world", cursor: 0)
        let handler = CodeBlockActionHandler()
        #expect(!handler.isActive(in: ctx))
    }

    // MARK: - activate

    @Test @MainActor
    func activateWrapWithFences() {
        let ctx = makeContext("Hello", cursor: 0, cursorEnd: 5)
        let handler = CodeBlockActionHandler()
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes.count == 2)
        // At line start → prefix is "```\n"
        #expect(edit!.changes.contains(.insert(at: 0, string: "```\n")))
        #expect(edit!.changes.contains(.insert(at: 5, string: "\n```")))
        #expect(edit!.selection == 4..<9)
    }

    // MARK: - deactivate

    @Test @MainActor
    func deactivateReturnsNil() {
        let text = "```\nhello\n```"
        let ctx = makeContext(text, cursor: 5)
        let handler = CodeBlockActionHandler()
        // deactivate not yet implemented
        #expect(handler.deactivate(in: ctx) == nil)
    }

    // MARK: - isEnabled

    @Test @MainActor
    func isEnabledOnParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        #expect(CodeBlockActionHandler().isEnabled(in: ctx))
    }

    @Test @MainActor
    func isEnabledInsideCodeBlock() {
        let ctx = makeContext("```\nhello\n```", cursor: 5)
        #expect(CodeBlockActionHandler().isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledOnHeading() {
        let ctx = makeContext("# Hello", cursor: 2)
        #expect(!CodeBlockActionHandler().isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledOnListItem() {
        let ctx = makeContext("- hello", cursor: 2)
        #expect(!CodeBlockActionHandler().isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledInsideBlockQuote() {
        let ctx = makeContext("> hello", cursor: 2)
        #expect(!CodeBlockActionHandler().isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledOnMultiLineSelection() {
        let ctx = makeContext("alpha\n\nbeta", cursor: 0, cursorEnd: 11)
        #expect(!CodeBlockActionHandler().isEnabled(in: ctx))
    }
}
