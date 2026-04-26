import Foundation

// MARK: - CodeBlockActionHandler

struct CodeBlockActionHandler: DocumentEditorActionHandler {

    func isActive(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return false }
        if case .codeBlock = markdown.currentTopLineToken() {
            return true
        }
        return false
    }

    func isEnabled(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return true }
        let tokens = markdown.selectionLineTokens()
        guard tokens.count <= 1 else { return false }
        switch tokens.first ?? nil {
        case nil, .paragraph, .codeBlock: return true
        default: return false
        }
    }

    func activate(in context: EditorContext) -> TextEdit? {
        let selection = context.selectionOffsets()
        let lineStart = context.currentLineRange().lowerBound

        let prefix = lineStart == selection.lowerBound ? "```\n" : "\n```\n"
        let suffix = "\n```"

        return TextEdit(
            changes: [
                .insert(at: selection.lowerBound, string: prefix),
                .insert(at: selection.upperBound, string: suffix)
            ],
            selection: selection.shifted(by: prefix.utf16.count)
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        nil
    }
}
