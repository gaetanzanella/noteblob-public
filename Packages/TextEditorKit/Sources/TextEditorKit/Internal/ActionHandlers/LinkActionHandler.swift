import Foundation

// MARK: - LinkActionHandler

/// Inserts a markdown link `[title](target)` at the selection. If the
/// selection is non-empty its text is used as the link title; otherwise the
/// provided `fallbackTitle` is used. `target` is written verbatim — the
/// caller is responsible for URL-encoding paths or constructing absolute
/// URLs. `]` characters in the chosen title are escaped to avoid prematurely
/// closing the link.
struct LinkActionHandler: DocumentEditorActionHandler {

    let target: String
    let fallbackTitle: String

    func isActive(in context: EditorContext) -> Bool {
        false
    }

    func activate(in context: EditorContext) -> TextEdit? {
        let selection = context.selectionOffsets()
        let text = context.currentText
        let selected: String
        if selection.isEmpty {
            selected = ""
        } else {
            let utf16 = text.utf16
            let start = utf16.index(utf16.startIndex, offsetBy: selection.lowerBound)
            let end = utf16.index(utf16.startIndex, offsetBy: selection.upperBound)
            selected = String(text[start..<end])
        }
        let rawTitle = selected.isEmpty ? fallbackTitle : selected
        let title = Self.escapeTitle(rawTitle)
        let markdown = "[\(title)](\(target))"
        let caret = selection.lowerBound + markdown.utf16.count
        return TextEdit(
            changes: [.replace(range: selection, with: markdown)],
            selection: caret..<caret
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        nil
    }

    private static func escapeTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}
