import Foundation

// MARK: - WrapActionHandler

/// Handles inline wrapping actions (bold, italic, code, strikethrough)
struct WrapActionHandler: DocumentEditorActionHandler {
    let mark: Mark

    func isActive(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return false }
        return markdown.currentInlineTokens().contains(inlineToken)
    }

    func activate(in context: EditorContext) -> TextEdit? {
        let selection = context.selectionOffsets()
        let wrapperUTF16 = wrapper.utf16.count
        return TextEdit(
            changes: [
                .insert(at: selection.lowerBound, string: wrapper),
                .insert(at: selection.upperBound, string: wrapper)
            ],
            selection: selection.shifted(by: wrapperUTF16)
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        guard let markdown = context.markdown(),
              let nodeRange = markdown.currentInlineRange(for: inlineToken) else {
            return nil
        }

        let selection = context.selectionOffsets()
        let wrapperUTF16 = wrapper.utf16.count

        return TextEdit(
            changes: [
                .delete(nodeRange.lowerBound..<(nodeRange.lowerBound + wrapperUTF16)),
                .delete((nodeRange.upperBound - wrapperUTF16)..<nodeRange.upperBound)
            ],
            selection: selection.shifted(by: -wrapperUTF16)
        )
    }

    // MARK: - Private

    private var wrapper: String {
        switch mark {
        case .bold: "**"
        case .italic: "*"
        case .strikethrough: "~~"
        case .inlineCode: "`"
        default: ""
        }
    }

    private var inlineToken: MarkdownInlineToken {
        switch mark {
        case .bold: .bold
        case .italic: .italic
        case .strikethrough: .strikethrough
        case .inlineCode: .inlineCode
        default: []
        }
    }
}
