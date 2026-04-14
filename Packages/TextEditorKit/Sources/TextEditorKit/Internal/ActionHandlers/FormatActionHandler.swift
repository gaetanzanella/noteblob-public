import Foundation
import Markdown

// MARK: - FormatActionHandler

struct FormatActionHandler: DocumentEditorActionHandler {

    func isActive(in context: EditorContext) -> Bool {
        false
    }

    func activate(in context: EditorContext) -> TextEdit? {
        let text = context.currentText
        guard !text.isEmpty else { return nil }

        var document = Document(parsing: text)

        // Rewrite: sort checked items after unchecked in each list
        var rewriter = CheckboxSortRewriter()
        if let rewritten = rewriter.visit(document) as? Document {
            document = rewritten
        }

        // Format with consistent style
        let options = MarkupFormatter.Options(
            unorderedListMarker: .dash,
            orderedListNumerals: .incrementing(start: 1)
        )
        let formatted = document.format(options: options)

        guard formatted != text else { return nil }

        let selection = context.selectionOffsets()
        let newCursor = min(selection.lowerBound, formatted.utf16.count)

        return TextEdit(
            changes: [.replace(range: 0..<text.utf16.count, with: formatted)],
            selection: newCursor..<newCursor
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        nil
    }
}

// MARK: - CheckboxSortRewriter

/// Reorders list items in unordered lists so that unchecked items appear before checked items.
/// Only affects lists that contain checkbox items.
private struct CheckboxSortRewriter: MarkupRewriter {

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> Markup? {
        // First, recursively rewrite children (nested lists)
        let rewrittenChildren = unorderedList.children.compactMap { visit($0) }
        let rewrittenList = unorderedList.withUncheckedChildren(rewrittenChildren)

        guard let list = rewrittenList as? UnorderedList else { return rewrittenList }

        let items = Array(list.listItems)
        let hasCheckboxes = items.contains { $0.checkbox != nil }
        guard hasCheckboxes else { return list }

        // Stable sort: unchecked and non-checkbox items first, checked items last
        let sorted = items.sorted { lhs, rhs in
            let lhsChecked = lhs.checkbox == .checked
            let rhsChecked = rhs.checkbox == .checked
            if lhsChecked != rhsChecked { return !lhsChecked }
            return false
        }

        return UnorderedList(sorted)
    }
}
