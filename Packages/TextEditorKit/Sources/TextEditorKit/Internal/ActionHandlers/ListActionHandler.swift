import Foundation

// MARK: - ListActionHandler

struct ListActionHandler: DocumentEditorActionHandler {
    let todo: Bool

    func isActive(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown(),
              case .listItem(let info) = markdown.currentTopLineToken() else {
            return false
        }

        if todo {
            return info.checkbox != nil
        } else {
            return info.checkbox == nil
        }
    }

    func activate(in context: EditorContext) -> TextEdit? {
        let prefix = todo ? "- [ ] " : "- "
        let prefixUTF16 = prefix.utf16.count
        let selection = context.selectionOffsets()
        let lineStart = context.currentLineRange().lowerBound

        if let markdown = context.markdown(),
           case .listItem(let info) = markdown.currentTopLineToken() {
            return TextEdit(
                changes: [.replace(range: lineStart..<(lineStart + info.prefixLength), with: prefix)],
                selection: selection.shifted(by: prefixUTF16 - info.prefixLength)
            )
        }

        return TextEdit(
            changes: [.insert(at: lineStart, string: prefix)],
            selection: selection.shifted(by: prefixUTF16)
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        guard let markdown = context.markdown(),
              case .listItem(let info) = markdown.currentTopLineToken() else {
            return nil
        }

        let selection = context.selectionOffsets()
        let lineStart = context.currentLineRange().lowerBound

        return TextEdit(
            changes: [.delete(lineStart..<(lineStart + info.prefixLength))],
            selection: selection.shifted(by: -info.prefixLength)
        )
    }
}
