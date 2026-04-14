import Foundation

// MARK: - HeadingActionHandler

struct HeadingActionHandler: DocumentEditorActionHandler {
    let level: Int

    func isActive(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return false }
        if case .heading(let currentLevel) = markdown.currentTopLineToken() {
            return currentLevel == level
        }
        return false
    }

    func activate(in context: EditorContext) -> TextEdit? {
        let prefix = String(repeating: "#", count: level) + " "
        let selection = context.selectionOffsets()
        let lineStart = context.currentLineRange().lowerBound
        let prefixUTF16 = prefix.utf16.count

        if let markdown = context.markdown(),
           case .heading(let currentLevel) = markdown.currentTopLineToken() {
            let oldPrefixLength = currentLevel + 1
            return TextEdit(
                changes: [.replace(range: lineStart..<(lineStart + oldPrefixLength), with: prefix)],
                selection: selection.shifted(by: prefixUTF16 - oldPrefixLength)
            )
        }

        return TextEdit(
            changes: [.insert(at: lineStart, string: prefix)],
            selection: selection.shifted(by: prefixUTF16)
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        guard let markdown = context.markdown(),
              case .heading(let currentLevel) = markdown.currentTopLineToken() else {
            return nil
        }

        let selection = context.selectionOffsets()
        let lineStart = context.currentLineRange().lowerBound
        let prefixLength = currentLevel + 1

        return TextEdit(
            changes: [.delete(lineStart..<(lineStart + prefixLength))],
            selection: selection.shifted(by: -prefixLength)
        )
    }
}
