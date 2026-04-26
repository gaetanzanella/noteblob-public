import Foundation

struct EditTableActionHandler: DocumentEditorActionHandler {

    let onRequest: @MainActor (TableEditingRequest) -> Void

    init(onRequest: @MainActor @escaping (TableEditingRequest) -> Void) {
        self.onRequest = onRequest
    }

    func isActive(in context: EditorContext) -> Bool {
        if case .table = context.markdown()?.currentTopLineToken() {
            return true
        }
        return false
    }

    func isEnabled(in context: EditorContext) -> Bool {
        true
    }

    func activate(in context: EditorContext) -> TextEdit? {
        emit(in: context)
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        emit(in: context)
    }

    /// Triggers the delegate with the table at the cursor (or empty), and —
    /// when there *is* a table at the cursor — returns a selection-only
    /// `TextEdit` that highlights the table's full range (including its
    /// trailing newline). The follow-up `.insert(.table(...))` then naturally
    /// replaces the highlighted range, leaving everything around it intact.
    private func emit(in context: EditorContext) -> TextEdit? {
        let info = currentTableInfo(in: context)
        let table: MarkdownTable
        if let info {
            table = MarkdownTable(headers: info.headers, rows: info.rows)
        } else {
            table = MarkdownTable(headers: [], rows: [])
        }
        onRequest(TableEditingRequest(currentTable: table))

        guard let info else { return nil }
        let layout = context.documentLayout
        let start = layout.lineRange(at: info.lineRange.lowerBound).lowerBound
        let end: Int
        if info.lineRange.upperBound < layout.lineCount {
            // Include the trailing newline so the replace round-trips cleanly.
            end = layout.lineRange(at: info.lineRange.upperBound).lowerBound
        } else {
            end = layout.lineRange(at: info.lineRange.upperBound - 1).upperBound
        }
        return TextEdit(changes: [], selection: start..<end)
    }

    private func currentTableInfo(in context: EditorContext) -> MarkdownLineToken.TableInfo? {
        if case .table(let info) = context.markdown()?.currentTopLineToken() {
            return info
        }
        return nil
    }
}
