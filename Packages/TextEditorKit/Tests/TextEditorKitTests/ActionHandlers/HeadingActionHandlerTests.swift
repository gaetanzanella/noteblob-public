import Testing
@testable import TextEditorKit

@Suite
struct HeadingActionHandlerTests {

    // MARK: - isActive

    @Test @MainActor
    func isActiveOnHeadingLine() {
        let ctx = makeContext("## Hello", cursor: 3)
        let handler = HeadingActionHandler(level: 2)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnDifferentLevel() {
        let ctx = makeContext("## Hello", cursor: 3)
        let handler = HeadingActionHandler(level: 1)
        #expect(!handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnParagraph() {
        let ctx = makeContext("Hello world", cursor: 0)
        let handler = HeadingActionHandler(level: 2)
        #expect(!handler.isActive(in: ctx))
    }

    // MARK: - activate

    @Test @MainActor
    func activateInsertsPrefixOnParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = HeadingActionHandler(level: 2)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 0, string: "## ")])
        #expect(edit!.selection == 3..<3)
    }

    @Test @MainActor
    func activateReplacesExistingHeading() {
        let ctx = makeContext("# Hello", cursor: 2)
        let handler = HeadingActionHandler(level: 3)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 0..<2, with: "### ")])
        // cursor was at 2, old prefix 2, new prefix 4 → 2 - 2 + 4 = 4
        #expect(edit!.selection == 4..<4)
    }

    // MARK: - deactivate

    @Test @MainActor
    func deactivateRemovesPrefix() {
        let ctx = makeContext("## Hello", cursor: 5)
        let handler = HeadingActionHandler(level: 2)
        let edit = handler.deactivate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<3)])
        // cursor was at 5, prefix 3 → 5 - 3 = 2
        #expect(edit!.selection == 2..<2)
    }

    @Test @MainActor
    func deactivateReturnsNilOnParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = HeadingActionHandler(level: 2)
        #expect(handler.deactivate(in: ctx) == nil)
    }
}
