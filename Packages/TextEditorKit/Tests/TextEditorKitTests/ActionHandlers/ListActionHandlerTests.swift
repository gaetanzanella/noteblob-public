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
    func activateReplacesExistingListWithTodo() {
        let ctx = makeContext("- Hello", cursor: 2)
        let handler = ListActionHandler(todo: true)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 0..<2, with: "- [ ] ")])
        // cursor was at 2, old prefix 2, new prefix 6 → 2 - 2 + 6 = 6
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
        // cursor was at 4, prefix 2 → 4 - 2 = 2
        #expect(edit!.selection == 2..<2)
    }

    @Test @MainActor
    func deactivateRemovesTodoPrefx() {
        let ctx = makeContext("- [ ] Task", cursor: 8)
        let handler = ListActionHandler(todo: true)
        let edit = handler.deactivate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes == [.delete(0..<6)])
        // cursor was at 8, prefix 6 → 8 - 6 = 2
        #expect(edit!.selection == 2..<2)
    }

    @Test @MainActor
    func deactivateReturnsNilOnParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        let handler = ListActionHandler(todo: false)
        #expect(handler.deactivate(in: ctx) == nil)
    }
}
