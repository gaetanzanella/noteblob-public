import Foundation

// MARK: - IndentActionHandler

struct IndentActionHandler: DocumentEditorActionHandler {

    private static let indentString = "  "
    private static let indentUTF16 = indentString.utf16.count

    let direction: Direction

    enum Direction {
        case indent
        case dedent
    }

    func isActive(in context: EditorContext) -> Bool {
        false
    }

    func isVisible(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return false }
        return markdown.currentListItemInfo() != nil
    }

    func isEnabled(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return false }
        guard let info = markdown.currentListItemInfo() else { return false }
        if direction == .dedent {
            return info.depth > 0
        }
        return true
    }

    func activate(in context: EditorContext) -> TextEdit? {
        switch direction {
        case .indent: return indentLine(in: context)
        case .dedent: return dedentLine(in: context)
        }
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        nil
    }

    // MARK: - Private

    private func indentLine(in context: EditorContext) -> TextEdit? {
        let lineStart = context.currentLineRange().lowerBound
        let selection = context.selectionOffsets()
        return TextEdit(
            changes: [.insert(at: lineStart, string: Self.indentString)],
            selection: selection.shifted(by: Self.indentUTF16)
        )
    }

    private func dedentLine(in context: EditorContext) -> TextEdit? {
        let lineRange = context.currentLineRange()
        let text = context.currentText
        let selection = context.selectionOffsets()

        let lineStart = lineRange.lowerBound
        let startIndex = String.Index(utf16Offset: lineStart, in: text)
        let lineEnd = String.Index(utf16Offset: lineRange.upperBound, in: text)
        let lineContent = text[startIndex..<lineEnd]

        // Count leading spaces to remove (up to 2)
        var spacesToRemove = 0
        for ch in lineContent {
            guard ch == " ", spacesToRemove < Self.indentUTF16 else { break }
            spacesToRemove += 1
        }

        guard spacesToRemove > 0 else { return nil }

        return TextEdit(
            changes: [.delete(lineStart..<(lineStart + spacesToRemove))],
            selection: selection.shifted(by: -spacesToRemove)
        )
    }
}
