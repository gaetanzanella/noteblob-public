import Foundation
import Markdown

struct TableActionHandler: DocumentEditorActionHandler {

    let table: MarkdownTable

    init(table: MarkdownTable) {
        self.table = table
    }

    func isActive(in context: EditorContext) -> Bool {
        false
    }

    func activate(in context: EditorContext) -> TextEdit? {
        let columnCount = table.headers.count
        guard columnCount > 0 else { return nil }

        let markdown = renderMarkdown(columnCount: columnCount)

        let selection = context.selectionOffsets()
        let lineStart = context.currentLineRange().lowerBound
        let cursorOnEmptyLine = selection.lowerBound == lineStart
        let prefix = cursorOnEmptyLine ? "" : "\n"
        let suffix = "\n"
        let inserted = prefix + markdown + suffix
        // Select the freshly inserted table block (the markdown plus its
        // trailing newline) — same shape as `EditTableActionHandler`'s
        // selection, so an immediate re-tap of the table button reopens the
        // editor sheet on the new table without the user having to first
        // place the cursor inside it.
        let selectionStart = selection.lowerBound + prefix.utf16.count
        let selectionEnd = selection.lowerBound + inserted.utf16.count
        return TextEdit(
            changes: [.replace(range: selection, with: inserted)],
            selection: selectionStart..<selectionEnd
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        nil
    }

    private func renderMarkdown(columnCount: Int) -> String {
        let header = Markdown.Table.Head(padded(table.headers, to: columnCount).map(makeCell))
        let body = Markdown.Table.Body(table.rows.map { row in
            Markdown.Table.Row(padded(row, to: columnCount).map(makeCell))
        })
        let alignments: [Markdown.Table.ColumnAlignment?] = Array(repeating: nil, count: columnCount)
        let mdTable = Markdown.Table(
            columnAlignments: alignments,
            header: header,
            body: body
        )
        // Wrap in a `Document` and format through the shared options so the
        // output matches `FormatActionHandler` byte-for-byte. Calling
        // `mdTable.format()` directly bypassed the document-level formatter
        // and produced subtly different whitespace, which made format-document
        // immediately rewrite a just-inserted table.
        let document = Markdown.Document([mdTable])
        return document.format(options: .documentDefault)
    }

    private func makeCell(_ text: String) -> Markdown.Table.Cell {
        Markdown.Table.Cell([Markdown.Text(sanitize(text))])
    }

    /// `MarkupFormatter` emits `Text` content verbatim — see swift-markdown's
    /// `visitText`. We:
    ///   - escape `|`/`\` so they don't reopen the cell or get parsed as
    ///     escape sequences on round-trip,
    ///   - replace `\n` with a space (cell rows can't span lines in GFM).
    /// Cells are *not* manually padded with surrounding spaces: the GFM
    /// parser trims a cell's leading/trailing whitespace when re-reading the
    /// table, so any padding we add is dropped on the next `formatDocument`.
    /// The shared `MarkupFormatter` already pads each cell with trailing
    /// spaces to the column's max width, which is enough to keep the output
    /// stable across insert ↔ format-document round-trips.
    private func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func padded(_ cells: [String], to count: Int) -> [String] {
        if cells.count >= count {
            return Array(cells.prefix(count))
        }
        return cells + Array(repeating: "", count: count - cells.count)
    }
}
