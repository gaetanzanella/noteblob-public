import Foundation

// MARK: - ListActionHandler

struct ListActionHandler: DocumentEditorActionHandler {
    let todo: Bool

    func isActive(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return false }
        let tokens = markdown.selectionLineTokens()
        guard !tokens.isEmpty else { return false }
        return tokens.allSatisfy(matchesMark)
    }

    func isEnabled(in context: EditorContext) -> Bool {
        guard let markdown = context.markdown() else { return true }
        return markdown.selectionLineTokens().allSatisfy { token in
            guard let token else { return true }
            switch token {
            case .paragraph, .listItem, .blockQuote: return true
            default: return false
            }
        }
    }

    func activate(in context: EditorContext) -> TextEdit? {
        guard let markdown = context.markdown() else { return nil }
        let prefix = self.prefix
        let prefixUTF16 = prefix.utf16.count
        var changes: [TextEdit.Change] = []
        var firstEditedLine: Int?
        var lastEditedLine = 0
        var totalDelta = 0

        for line in context.selectionLineRange {
            let token = markdown.topLineToken(at: line)
            let lineStart = context.lineRange(at: line).lowerBound
            let delta: Int
            if case .listItem(let info) = token {
                if matchesMark(token) { continue }
                let markerLength = info.marker.utf16.count + 1 + (info.checkbox != nil ? 4 : 0)
                let markerStart = lineStart + info.prefixLength - markerLength
                changes.append(.replace(range: markerStart..<(lineStart + info.prefixLength), with: prefix))
                delta = prefixUTF16 - markerLength
            } else if token == nil {
                // In multi-line selections, blank lines between blocks
                // shouldn't become empty list items. A single-line cursor
                // on a blank line (e.g. an empty document) still gets the
                // prefix so the user can start typing.
                if context.selectionLineRange.count > 1 { continue }
                changes.append(.insert(at: lineStart, string: prefix))
                delta = prefixUTF16
            } else {
                changes.append(.insert(at: lineStart, string: prefix))
                delta = prefixUTF16
            }
            firstEditedLine = firstEditedLine ?? line
            lastEditedLine = line
            totalDelta += delta
        }

        return buildEdit(
            context: context,
            changes: changes,
            firstEditedLine: firstEditedLine,
            lastEditedLine: lastEditedLine,
            totalDelta: totalDelta
        )
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        guard let markdown = context.markdown() else { return nil }
        var changes: [TextEdit.Change] = []
        var firstEditedLine: Int?
        var lastEditedLine = 0
        var totalDelta = 0

        for line in context.selectionLineRange {
            guard case .listItem(let info) = markdown.topLineToken(at: line) else { continue }
            let lineStart = context.lineRange(at: line).lowerBound
            changes.append(.delete(lineStart..<(lineStart + info.prefixLength)))
            firstEditedLine = firstEditedLine ?? line
            lastEditedLine = line
            totalDelta += -info.prefixLength
        }

        return buildEdit(
            context: context,
            changes: changes,
            firstEditedLine: firstEditedLine,
            lastEditedLine: lastEditedLine,
            totalDelta: totalDelta
        )
    }

    // MARK: - Private

    /// Builds the final TextEdit. For single-line edits the user's selection
    /// is preserved (just shifted by the edit delta) so the cursor lands
    /// where they expect. For multi-line edits the post-edit selection
    /// covers the whole produced/stripped list block.
    private func buildEdit(
        context: EditorContext,
        changes: [TextEdit.Change],
        firstEditedLine: Int?,
        lastEditedLine: Int,
        totalDelta: Int
    ) -> TextEdit? {
        guard !changes.isEmpty, let firstEditedLine else { return nil }
        let selection: Range<Int>
        if context.selectionLineRange.count == 1 {
            let firstLineStart = context.lineRange(at: firstEditedLine).lowerBound
            selection = context.selectionOffsets()
                .shifted(by: totalDelta, floor: firstLineStart)
        } else {
            let firstLineStart = context.lineRange(at: firstEditedLine).lowerBound
            let lastLineEnd = context.lineRange(at: lastEditedLine).upperBound
            selection = firstLineStart..<(lastLineEnd + totalDelta)
        }
        return TextEdit(changes: changes, selection: selection)
    }

    private var prefix: String { todo ? "- [ ] " : "- " }

    private func matchesMark(_ token: MarkdownLineToken?) -> Bool {
        guard case .listItem(let info) = token else { return false }
        return todo ? info.checkbox != nil : info.checkbox == nil
    }
}
