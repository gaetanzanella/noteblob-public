import Foundation

// MARK: - MarkdownDocumentLayout

@MainActor
final class MarkdownDocumentLayout: DocumentLayoutInvalidating {

    // MARK: - State

    private var text: String
    private var lineIndex: LineIndex
    private var blockIndex: BlockIndex

    // MARK: - Init

    init() {
        self.text = ""
        self.lineIndex = LineIndex()
        self.blockIndex = BlockIndex()
    }

    // MARK: - Update

    func setText(_ newText: String) {
        self.text = newText
        self.lineIndex = LineIndex(text: newText)
        self.blockIndex = BlockIndex(parsing: newText)
    }

    func update(
        newText: String,
        changedRange: Range<Int>,
        replacementLength: Int
    ) {
        // 1. Find affected region BEFORE patching
        let editLine = lineIndex.lineNumber(at: changedRange.lowerBound)
        let (oldStart, oldEnd, replaceRange) = blockIndex.affectedRegion(
            editLine: editLine,
            lineCount: lineIndex.lineCount
        )

        // 2. Patch line offsets
        let oldLineCount = lineIndex.lineCount
        self.text = newText
        lineIndex.applyEdit(
            replacingRange: changedRange,
            withLength: replacementLength,
            in: newText
        )
        let lineDelta = lineIndex.lineCount - oldLineCount

        // 3. Extract affected region in new text and update index
        let regionStart = oldStart
        let regionEnd = max(oldEnd, oldEnd + lineDelta)
        let regionText = extractText(fromLine: regionStart, toLine: regionEnd)

        blockIndex.applyEdit(
            replacing: replaceRange,
            withRegionText: regionText,
            regionStartLine: regionStart,
            lineDelta: lineDelta
        )
    }

    // MARK: - Queries

    func lineToken(at line: Int) -> MarkdownLineToken? {
        blockIndex.topLineToken(at: line)
    }

    func inlineTokens(at position: SourcePosition) -> MarkdownInlineToken {
        blockIndex.inlineTokens(at: position)
    }

    func inlineRange(at position: SourcePosition, token: MarkdownInlineToken) -> Range<Int>? {
        guard let columnRange = blockIndex.inlineRange(at: position, token: token) else { return nil }
        let lineStart = lineIndex.lineStart(at: position.line)
        return (lineStart + columnRange.lowerBound)..<(lineStart + columnRange.upperBound)
    }

    // MARK: - Coordinates

    var lineCount: Int { lineIndex.lineCount }
    func lineRange(at line: Int) -> Range<Int> { lineIndex.lineRange(at: line) }
    func offset(of position: SourcePosition) -> Int { lineIndex.offset(of: position) }
    func sourcePosition(at offset: Int) -> SourcePosition { lineIndex.sourcePosition(at: offset) }

    // MARK: - Private

    private func extractText(fromLine startLine: Int, toLine endLine: Int) -> String {
        guard startLine <= endLine, startLine < lineIndex.lineCount else { return "" }
        let endLine = min(endLine, lineIndex.lineCount - 1)

        let startOffset = lineIndex.lineStart(at: startLine)
        let utf16Length = text.utf16.count
        guard startOffset < utf16Length else { return "" }

        let endOffset = min(
            endLine + 1 < lineIndex.lineCount ? lineIndex.lineStart(at: endLine + 1) : utf16Length,
            utf16Length
        )

        let start = String.Index(utf16Offset: startOffset, in: text)
        let end = String.Index(utf16Offset: endOffset, in: text)
        return String(text[start..<end])
    }
}
