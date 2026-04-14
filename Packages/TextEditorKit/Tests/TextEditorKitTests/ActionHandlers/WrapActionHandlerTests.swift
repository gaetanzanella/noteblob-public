import Testing
@testable import TextEditorKit

@Suite
struct WrapActionHandlerTests {

    // MARK: - isActive

    @Test @MainActor
    func isActiveInsideBold() {
        let ctx = makeContext("Hello **world** end", cursor: 10)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOutsideBold() {
        let ctx = makeContext("Hello **world** end", cursor: 2)
        let handler = WrapActionHandler(mark: .bold)
        #expect(!handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveInsideItalic() {
        let ctx = makeContext("Hello *world* end", cursor: 8)
        let handler = WrapActionHandler(mark: .italic)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveInsideInlineCode() {
        let ctx = makeContext("Hello `code` end", cursor: 8)
        let handler = WrapActionHandler(mark: .inlineCode)
        #expect(handler.isActive(in: ctx))
    }

    // MARK: - activate

    @Test @MainActor
    func activateWrapsBold() {
        let ctx = makeContext("Hello", cursor: 0, cursorEnd: 5)
        let handler = WrapActionHandler(mark: .bold)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes.count == 2)
        #expect(edit!.changes.contains(.insert(at: 0, string: "**")))
        #expect(edit!.changes.contains(.insert(at: 5, string: "**")))
        #expect(edit!.selection == 2..<7)
    }

    @Test @MainActor
    func activateWrapsItalic() {
        let ctx = makeContext("Hello", cursor: 0, cursorEnd: 5)
        let handler = WrapActionHandler(mark: .italic)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.selection == 1..<6)
    }

    // MARK: - deactivate

    @Test @MainActor
    func deactivateRemovesBoldMarkers() {
        let ctx = makeContext("**Hello**", cursor: 2, cursorEnd: 7)
        let handler = WrapActionHandler(mark: .bold)
        let edit = handler.deactivate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes.count == 2)
        // Should delete the opening ** and closing **
        #expect(edit!.changes.contains(.delete(0..<2)))
        #expect(edit!.changes.contains(.delete(7..<9)))
        #expect(edit!.selection == 0..<5)
    }

    @Test @MainActor
    func deactivateReturnsNilOnPlainText() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.deactivate(in: ctx) == nil)
    }
}
