import Foundation

// MARK: - ListContinuationInterceptor

/// On Enter after a list item, inserts the next list prefix.
/// On Enter on an empty list item, removes the prefix (exits the list).
///
/// Note: By the time this interceptor runs, UIKit has already inserted the newline.
/// The cursor is on the NEW line. We check the PREVIOUS line for list context.
struct ListContinuationInterceptor: TypeInterceptor {

    var priority: Int { 0 }

    func intercept(_ context: TypeContext) -> TextEdit? {
        guard context.isNewline else { return nil }

        let currentLine = context.editorContext.currentLine
        guard currentLine > 0 else { return nil }

        let previousLine = currentLine - 1
        guard let markdown = context.editorContext.markdown(),
              case .listItem(let info) = markdown.topLineToken(at: previousLine) else {
            return nil
        }

        let previousLineRange = context.editorContext.lineRange(at: previousLine)
        let cursorOffset = context.editorContext.selectionOffsets().lowerBound

        // Empty list item → remove prefix and newline (exit list)
        if isEmptyListItem(lineRange: previousLineRange, info: info) {
            return TextEdit(
                changes: [.delete(previousLineRange.lowerBound..<cursorOffset)],
                selection: previousLineRange.lowerBound..<previousLineRange.lowerBound
            )
        }

        // Current line already has a list item → don't duplicate
        if case .listItem = markdown.topLineToken(at: currentLine) {
            return nil
        }

        // Continue with next prefix
        let continuation = info.continuationPrefix()
        let continuationUTF16 = continuation.utf16.count
        return TextEdit(
            changes: [.insert(at: cursorOffset, string: continuation)],
            selection: (cursorOffset + continuationUTF16)..<(cursorOffset + continuationUTF16)
        )
    }

    // MARK: - Private

    private func isEmptyListItem(lineRange: Range<Int>, info: MarkdownLineToken.ListItemInfo) -> Bool {
        let lineLength = lineRange.upperBound - lineRange.lowerBound
        return lineLength <= info.prefixLength
    }
}
