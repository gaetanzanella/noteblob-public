import Foundation

// MARK: - WrapActionHandler

/// Handles inline wrapping actions (bold, italic, code, strikethrough)
struct WrapActionHandler: DocumentEditorActionHandler {
    let mark: Mark

    func isActive(in context: EditorContext) -> Bool {
        if let markdown = context.markdown(),
           markdown.currentInlineTokens().contains(inlineToken) {
            return true
        }
        // Defer to a wider wrapper that reuses the same character (e.g. the
        // inner `*` of a bold `**` must not register as italic).
        for parent in dependencies {
            if WrapActionHandler(mark: parent).isActive(in: context) {
                return false
            }
        }
        let selection = context.selectionOffsets()
        if selection.isEmpty {
            // A collapsed cursor in an empty wrapper (e.g. `****` / `**`)
            // — the parser usually misses these, so check for matching
            // wrappers flanking the cursor.
            return hasFlankingWrappers(in: context)
        }
        // Non-empty selection: the parser is authoritative for what sits
        // between chars, so don't consult flanking (it would misfire on
        // things like "**a**bc**d**"). But if the selection itself
        // contains wrappers at its edges, treat that as active.
        return hasContainedWrappers(in: context)
    }

    func isEnabled(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return true }
        let tokens = markdown.selectionLineTokens()
        guard tokens.count <= 1 else { return false }
        switch tokens.first ?? nil {
        case .codeBlock, .thematicBreak, .table, .htmlBlock: return false
        default: return true
        }
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
        let selection = context.selectionOffsets()
        let wrapperUTF16 = wrapper.utf16.count
        // Strip wrappers just outside the selection (adjacent markers).
        if hasFlankingWrappers(in: context) {
            return TextEdit(
                changes: [
                    .delete((selection.lowerBound - wrapperUTF16)..<selection.lowerBound),
                    .delete(selection.upperBound..<(selection.upperBound + wrapperUTF16))
                ],
                selection: selection.shifted(by: -wrapperUTF16)
            )
        }
        // Strip wrappers that sit inside the selection at its edges — when
        // the user selected the markers along with the content.
        if hasContainedWrappers(in: context) {
            return TextEdit(
                changes: [
                    .delete(selection.lowerBound..<(selection.lowerBound + wrapperUTF16)),
                    .delete((selection.upperBound - wrapperUTF16)..<selection.upperBound)
                ],
                selection: selection.lowerBound..<(selection.upperBound - 2 * wrapperUTF16)
            )
        }
        return activate(in: context)
    }

    // MARK: - Private

    /// True iff the characters immediately before `selection.lowerBound` and
    /// immediately after `selection.upperBound` both equal `wrapper` — and
    /// aren't part of a longer run of the same character (which would mean
    /// the flanking is actually the inner half of a wider wrapper, e.g. the
    /// italic `*` inside a bold `**`).
    private func hasFlankingWrappers(in context: EditorContext) -> Bool {
        let selection = context.selectionOffsets()
        let wrapperUTF16 = wrapper.utf16.count
        let utf16 = context.currentText.utf16
        let start = utf16.startIndex
        let end = utf16.endIndex
        guard let selLower = utf16.index(start, offsetBy: selection.lowerBound, limitedBy: end),
              let selUpper = utf16.index(start, offsetBy: selection.upperBound, limitedBy: end),
              let openStart = utf16.index(selLower, offsetBy: -wrapperUTF16, limitedBy: start),
              let closeEnd = utf16.index(selUpper, offsetBy: wrapperUTF16, limitedBy: end)
        else {
            return false
        }
        return utf16[openStart..<selLower].elementsEqual(wrapper.utf16)
            && utf16[selUpper..<closeEnd].elementsEqual(wrapper.utf16)
    }

    /// True iff the first and last `wrapperUTF16` code units of the selection
    /// both equal `wrapper` — i.e. the user selected the markers along with
    /// the content they wrap.
    private func hasContainedWrappers(in context: EditorContext) -> Bool {
        let selection = context.selectionOffsets()
        let wrapperUTF16 = wrapper.utf16.count
        guard selection.upperBound - selection.lowerBound >= 2 * wrapperUTF16 else {
            return false
        }
        let utf16 = context.currentText.utf16
        let start = utf16.startIndex
        let end = utf16.endIndex
        guard let selLower = utf16.index(start, offsetBy: selection.lowerBound, limitedBy: end),
              let selUpper = utf16.index(start, offsetBy: selection.upperBound, limitedBy: end),
              let openEnd = utf16.index(selLower, offsetBy: wrapperUTF16, limitedBy: selUpper),
              let closeStart = utf16.index(selUpper, offsetBy: -wrapperUTF16, limitedBy: selLower)
        else {
            return false
        }
        return utf16[selLower..<openEnd].elementsEqual(wrapper.utf16)
            && utf16[closeStart..<selUpper].elementsEqual(wrapper.utf16)
    }

    /// Wider wrappers that share our first character. When any of them is
    /// active at the selection we suppress our own flanking check, because
    /// its inner characters could be mistaken for ours (e.g. italic `*`
    /// inside bold `**`).
    private var dependencies: [Mark] {
        switch mark {
        case .italic: [.bold]
        default: []
        }
    }

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
