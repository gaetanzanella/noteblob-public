import Testing

@testable import TextEditorKit

@Suite
struct IndentActionHandlerTests {

    // MARK: - Indent

    @Test @MainActor
    func indentAddsSpacesAtLineStart() {
        let handler = IndentActionHandler(direction: .indent)
        let ctx = makeContext("- Hello", cursor: 7)

        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 0, string: "  ")])
        #expect(edit!.selection == 9..<9)
    }

    @Test @MainActor
    func indentWithCursorInMiddle() {
        let handler = IndentActionHandler(direction: .indent)
        let ctx = makeContext("- Hello", cursor: 4)

        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.insert(at: 0, string: "  ")])
        #expect(edit!.selection == 6..<6)
    }

    // MARK: - Dedent

    @Test @MainActor
    func dedentRemovesLeadingSpaces() {
        let handler = IndentActionHandler(direction: .dedent)
        let ctx = makeContext("  - Hello", cursor: 9)

        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<2)])
        #expect(edit!.selection == 7..<7)
    }

    @Test @MainActor
    func dedentRemovesOnlyOneSpace() {
        let handler = IndentActionHandler(direction: .dedent)
        let ctx = makeContext(" - Hello", cursor: 8)

        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<1)])
        #expect(edit!.selection == 7..<7)
    }

    @Test @MainActor
    func dedentNoOpWithoutLeadingSpaces() {
        let handler = IndentActionHandler(direction: .dedent)
        let ctx = makeContext("- Hello", cursor: 7)

        let edit = handler.activate(in: ctx)

        #expect(edit == nil)
    }

    // MARK: - Visibility

    @Test @MainActor
    func notVisibleOnParagraph() {
        let handler = IndentActionHandler(direction: .indent)
        let ctx = makeContext("Hello", cursor: 5)

        #expect(handler.isVisible(in: ctx) == false)
    }

    @Test @MainActor
    func visibleOnListItem() {
        let handler = IndentActionHandler(direction: .indent)
        let ctx = makeContext("- Hello", cursor: 7)

        #expect(handler.isVisible(in: ctx) == true)
    }

    // MARK: - isActive

    @Test @MainActor
    func neverActive() {
        let handler = IndentActionHandler(direction: .indent)
        let ctx = makeContext("- Hello", cursor: 7)

        #expect(handler.isActive(in: ctx) == false)
    }
}
