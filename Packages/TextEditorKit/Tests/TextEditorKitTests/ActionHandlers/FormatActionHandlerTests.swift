import Testing

@testable import TextEditorKit

@Suite
struct FormatActionHandlerTests {

    private let handler = FormatActionHandler()

    // MARK: - Checkbox Sorting

    @Test @MainActor
    func sortsCheckedItemsAfterUnchecked() {
        let text = "- [x] Done\n- [ ] Todo\n- [x] Also done\n- [ ] Another"
        let ctx = makeContext(text, cursor: 0)

        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        let result = applyEdit(edit!, to: text)
        #expect(result == "- [ ] Todo\n- [ ] Another\n- [x] Done\n- [x] Also done")
    }

    @Test @MainActor
    func preservesNonCheckboxLists() {
        let text = "- Banana\n- Apple"
        let ctx = makeContext(text, cursor: 0)

        let edit = handler.activate(in: ctx)

        // Already formatted — no edit needed
        #expect(edit == nil)
    }

    @Test @MainActor
    func sortsNestedCheckboxLists() {
        let text = "- [ ] Parent\n  - [x] Child done\n  - [ ] Child todo"
        let ctx = makeContext(text, cursor: 0)

        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        let result = applyEdit(edit!, to: text)
        #expect(result == "- [ ] Parent\n  - [ ] Child todo\n  - [x] Child done")
    }

    // MARK: - Formatting

    @Test @MainActor
    func formatsInconsistentMarkers() {
        // Using same marker so cmark parses as one list
        let text = "* Item one\n* Item two\n* Item three"
        let ctx = makeContext(text, cursor: 0)

        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        let result = applyEdit(edit!, to: text)
        #expect(result == "- Item one\n- Item two\n- Item three")
    }

    @Test @MainActor
    func noEditOnAlreadyFormatted() {
        let text = "- [ ] Todo\n- [x] Done"
        let ctx = makeContext(text, cursor: 0)

        #expect(handler.activate(in: ctx) == nil)
    }

    @Test @MainActor
    func emptyTextReturnsNil() {
        let ctx = makeContext("", cursor: 0)
        #expect(handler.activate(in: ctx) == nil)
    }

    @Test @MainActor
    func neverActive() {
        let ctx = makeContext("- Item", cursor: 0)
        #expect(handler.isActive(in: ctx) == false)
    }

}
