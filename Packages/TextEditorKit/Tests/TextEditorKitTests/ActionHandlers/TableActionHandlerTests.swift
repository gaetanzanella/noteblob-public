import Testing

@testable import TextEditorKit

@Suite
struct TableActionHandlerTests {

    @Test @MainActor
    func activateInsertsRenderedMarkdownInEmptyDocument() {
        let ctx = makeContext("", cursor: 0)
        let table = MarkdownTable(headers: ["A", "B"], rows: [["1", "2"]])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        let expected = "|A|B|\n|-|-|\n|1|2|\n"
        #expect(edit?.changes == [.replace(range: 0..<0, with: expected)])
    }

    @Test @MainActor
    func activateOmitsLeadingNewlineAtLineStart() {
        let ctx = makeContext("Hello", cursor: 0)
        let table = MarkdownTable(headers: ["A"], rows: [])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        #expect(edit?.changes == [.replace(range: 0..<0, with: "|A|\n|-|\n")])
    }

    @Test @MainActor
    func activateAddsLeadingNewlineWhenCursorIsMidLine() {
        let ctx = makeContext("Hello", cursor: 3)
        let table = MarkdownTable(headers: ["A"], rows: [])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        #expect(edit?.changes == [.replace(range: 3..<3, with: "\n|A|\n|-|\n")])
    }

    @Test @MainActor
    func activateOmitsLeadingNewlineAtStartOfBlankLine() {
        let ctx = makeContext("Hello\n", cursor: 6)
        let table = MarkdownTable(headers: ["A"], rows: [])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        #expect(edit?.changes == [.replace(range: 6..<6, with: "|A|\n|-|\n")])
    }

    @Test @MainActor
    func activateReplacesSelectionWithTable() {
        let ctx = makeContext("foo bar", cursor: 0, cursorEnd: 3)
        let table = MarkdownTable(headers: ["A"], rows: [])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        #expect(edit?.changes == [.replace(range: 0..<3, with: "|A|\n|-|\n")])
    }

    @Test @MainActor
    func activateSelectsInsertedTable() {
        let ctx = makeContext("", cursor: 0)
        let table = MarkdownTable(headers: ["A"], rows: [["1"]])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        let inserted = "|A|\n|-|\n|1|\n"
        #expect(edit?.selection == 0..<inserted.utf16.count)
    }

    @Test @MainActor
    func activateSelectsInsertedTableExcludingLeadingNewline() {
        let ctx = makeContext("Hello", cursor: 3)
        let table = MarkdownTable(headers: ["A"], rows: [])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        // Inserted is `\n|A|\n|-|\n` at offset 3 — selection should skip
        // the leading `\n` so it covers exactly the table block + its
        // trailing newline.
        #expect(edit?.selection == 4..<12)
    }

    @Test @MainActor
    func activateEscapesPipeInCells() {
        let ctx = makeContext("", cursor: 0)
        let table = MarkdownTable(headers: ["a|b"], rows: [["c|d"]])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        // Escaping `|` to `\|` makes each cell 4 chars (`a\|b`), so the dash
        // row is `----`.
        #expect(edit?.changes == [.replace(range: 0..<0, with: "|a\\|b|\n|----|\n|c\\|d|\n")])
    }

    @Test @MainActor
    func activateEscapesBackslashInCells() {
        let ctx = makeContext("", cursor: 0)
        // Source `"a\\b"` is the 3-char string `a\b`; escaping doubles it to
        // `a\\b` (4 chars), so the column width is 4 too.
        let table = MarkdownTable(headers: ["a\\b"], rows: [])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        #expect(edit?.changes == [.replace(range: 0..<0, with: "|a\\\\b|\n|----|\n")])
    }

    @Test @MainActor
    func activateReplacesNewlineInCellsWithSpace() {
        let ctx = makeContext("", cursor: 0)
        let table = MarkdownTable(headers: ["A"], rows: [["one\ntwo"]])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        // Body cell `one two` is 7 chars; the header pads with trailing
        // spaces to match, and the dash row is 7 dashes.
        #expect(edit?.changes == [.replace(range: 0..<0, with: "|A      |\n|-------|\n|one two|\n")])
    }

    @Test @MainActor
    func activatePadsShortRowsWithEmptyCells() {
        let ctx = makeContext("", cursor: 0)
        let table = MarkdownTable(headers: ["A", "B", "C"], rows: [["1"]])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        // Empty cells become a single space (column width = 1, the formatter
        // pads `""` with one trailing space).
        #expect(edit?.changes == [.replace(range: 0..<0, with: "|A|B|C|\n|-|-|-|\n|1| | |\n")])
    }

    @Test @MainActor
    func activateTruncatesRowsLongerThanColumnCount() {
        let ctx = makeContext("", cursor: 0)
        let table = MarkdownTable(headers: ["A"], rows: [["1", "extra", "more"]])
        let handler = TableActionHandler(table: table)

        let edit = handler.activate(in: ctx)

        #expect(edit?.changes == [.replace(range: 0..<0, with: "|A|\n|-|\n|1|\n")])
    }

    @Test @MainActor
    func activateReturnsNilWhenHeadersAreEmpty() {
        let ctx = makeContext("", cursor: 0)
        let table = MarkdownTable(headers: [], rows: [])
        let handler = TableActionHandler(table: table)

        #expect(handler.activate(in: ctx) == nil)
    }

    @Test @MainActor
    func isActiveIsAlwaysFalse() {
        let ctx = makeContext("anything", cursor: 0)
        let handler = TableActionHandler(table: MarkdownTable(headers: ["A"], rows: []))
        #expect(!handler.isActive(in: ctx))
    }

    @Test @MainActor
    func deactivateReturnsNil() {
        let ctx = makeContext("anything", cursor: 0)
        let handler = TableActionHandler(table: MarkdownTable(headers: ["A"], rows: []))
        #expect(handler.deactivate(in: ctx) == nil)
    }
}
