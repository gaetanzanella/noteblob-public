import Testing

@testable import TextEditorKit

@Suite
struct EditTableActionHandlerTests {

    // MARK: - isActive

    @Test @MainActor
    func isActiveOnTableLine() {
        let text = "| h1 | h2 |\n| --- | --- |\n| 1 | 2 |\n"
        let ctx = makeContext(text, cursor: 5)
        #expect(EditTableActionHandler(onRequest: { _ in }).isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveOnTableSeparatorLine() {
        let text = "| h1 | h2 |\n| --- | --- |\n| 1 | 2 |\n"
        let ctx = makeContext(text, cursor: 14)
        #expect(EditTableActionHandler(onRequest: { _ in }).isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveOnTableBodyLine() {
        let text = "| h1 | h2 |\n| --- | --- |\n| 1 | 2 |\n"
        let ctx = makeContext(text, cursor: 28)
        #expect(EditTableActionHandler(onRequest: { _ in }).isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnParagraph() {
        let ctx = makeContext("just a paragraph", cursor: 4)
        #expect(!EditTableActionHandler(onRequest: { _ in }).isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnHeading() {
        let ctx = makeContext("# Heading", cursor: 4)
        #expect(!EditTableActionHandler(onRequest: { _ in }).isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveInEmptyDocument() {
        let ctx = makeContext("", cursor: 0)
        #expect(!EditTableActionHandler(onRequest: { _ in }).isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOnLineAboveTable() {
        let text = "before\n\n| h |\n| - |\n| 1 |\n"
        let ctx = makeContext(text, cursor: 0)
        #expect(!EditTableActionHandler(onRequest: { _ in }).isActive(in: ctx))
    }

    @Test @MainActor
    func isEnabledIsAlwaysTrue() {
        let ctx = makeContext("anything", cursor: 0)
        #expect(EditTableActionHandler(onRequest: { _ in }).isEnabled(in: ctx))
    }

    // MARK: - Off-table — no edit, empty request

    @Test @MainActor
    func activateInEmptyDocumentDeliversEmptyTableAndNoEdit() {
        let ctx = makeContext("", cursor: 0)
        var received: TableEditingRequest?
        let edit = EditTableActionHandler(onRequest: { received = $0 }).activate(in: ctx)

        #expect(edit == nil)
        #expect(received?.currentTable.headers.isEmpty == true)
        #expect(received?.currentTable.rows.isEmpty == true)
    }

    @Test @MainActor
    func activateInParagraphDeliversEmptyTableAndNoEdit() {
        let ctx = makeContext("just a paragraph", cursor: 4)
        var received: TableEditingRequest?
        let edit = EditTableActionHandler(onRequest: { received = $0 }).activate(in: ctx)

        #expect(edit == nil)
        #expect(received?.currentTable.headers.isEmpty == true)
    }

    @Test @MainActor
    func activateOutsideTableInDocWithTableDeliversEmptyTable() {
        let text = "Paragraph above\n\n|h|\n|-|\n|x|\n"
        let ctx = makeContext(text, cursor: 3)
        var received: TableEditingRequest?
        let edit = EditTableActionHandler(onRequest: { received = $0 }).activate(in: ctx)

        #expect(edit == nil)
        #expect(received?.currentTable.headers.isEmpty == true)
    }

    @Test @MainActor
    func deactivateReturnsNilOffTable() {
        let ctx = makeContext("a paragraph", cursor: 2)
        #expect(EditTableActionHandler(onRequest: { _ in }).deactivate(in: ctx) == nil)
    }

    // MARK: - On-table — parsed request, selection covers the block

    @Test @MainActor
    func activateOnHeaderLineDeliversParsedTable() {
        let text = "|h|\n|-|\n|x|\n"
        let ctx = makeContext(text, cursor: 1)
        var received: TableEditingRequest?
        _ = EditTableActionHandler(onRequest: { received = $0 }).activate(in: ctx)

        #expect(received?.currentTable.headers == ["h"])
        #expect(received?.currentTable.rows == [["x"]])
    }

    @Test @MainActor
    func activateOnBodyLineDeliversParsedTableAndSelectsBlock() {
        let text = "|h1|h2|\n|-|-|\n|a|b|\n"
        let ctx = makeContext(text, cursor: 16)
        var received: TableEditingRequest?
        let edit = EditTableActionHandler(onRequest: { received = $0 }).activate(in: ctx)

        #expect(received?.currentTable.headers == ["h1", "h2"])
        #expect(received?.currentTable.rows == [["a", "b"]])
        #expect(edit?.changes.isEmpty == true)
        #expect(edit?.selection == 0..<text.utf16.count)
    }
}
