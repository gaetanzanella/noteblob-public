import Testing

@testable import TextEditorKit

@Suite
struct LinkActionHandlerTests {

    @Test @MainActor
    func activateInsertsMarkdownAtCaret() {
        let ctx = makeContext("Hello ", cursor: 6)
        let handler = LinkActionHandler(target: "foo.md", fallbackTitle: "Foo")
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 6..<6, with: "[Foo](foo.md)")])
        #expect(edit!.selection == 19..<19)
    }

    @Test @MainActor
    func activateUsesSelectionAsTitle() {
        let ctx = makeContext("see this later", cursor: 4, cursorEnd: 8)
        let handler = LinkActionHandler(target: "notes/t.md", fallbackTitle: "fallback")
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 4..<8, with: "[this](notes/t.md)")])
        #expect(edit!.selection == 22..<22)
    }

    @Test @MainActor
    func activateEscapesClosingBracketInTitle() {
        let ctx = makeContext("", cursor: 0)
        let handler = LinkActionHandler(target: "t.md", fallbackTitle: "a]b")
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 0..<0, with: "[a\\]b](t.md)")])
    }

    @Test @MainActor
    func isActiveIsAlwaysFalse() {
        let ctx = makeContext("x", cursor: 0)
        let handler = LinkActionHandler(target: "t.md", fallbackTitle: "t")
        #expect(!handler.isActive(in: ctx))
    }

    @Test @MainActor
    func deactivateReturnsNil() {
        let ctx = makeContext("x", cursor: 0)
        let handler = LinkActionHandler(target: "t.md", fallbackTitle: "t")
        #expect(handler.deactivate(in: ctx) == nil)
    }
}
