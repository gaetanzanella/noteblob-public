import Foundation

// MARK: - ListIndentInterceptor

/// On Tab inside a list item, indents by adding 2 spaces at line start.
/// The Tab character itself is consumed and not inserted.
///
/// Note: By the time this interceptor runs, the text view has already inserted
/// the tab character. The cursor sits right after the tab.
struct ListIndentInterceptor: TypeInterceptor {

    var priority: Int { 0 }

    func intercept(_ context: TypeContext) -> TextEdit? {
        guard context.isTab else { return nil }
        guard let markdown = context.editorContext.markdown(),
              markdown.currentListItemInfo() != nil else {
            return nil
        }

        let lineStart = context.editorContext.currentLineRange().lowerBound
        let cursor = context.editorContext.selectionOffsets().lowerBound
        let indent = "  "
        let indentUTF16 = indent.utf16.count

        // Tab character is right before cursor
        let tabStart = cursor - 1

        // New cursor: original position (before tab) shifted by indent
        let newCursor = tabStart + indentUTF16

        return TextEdit(
            changes: [
                .delete(tabStart..<cursor),
                .insert(at: lineStart, string: indent),
            ],
            selection: newCursor..<newCursor
        )
    }
}
