import Foundation
import Markdown

// MARK: - BlockIndex

/// Lookup index mapping lines to top-level blocks.
struct BlockIndex {

    struct Block {
        let markup: BlockMarkup
        let lineRange: Range<Int> // 0-based
    }

    // MARK: - Properties

    private var blocks: [Block]

    var count: Int { blocks.count }

    // MARK: - Init

    init() {
        self.blocks = []
    }

    init(parsing text: String) {
        let document = Document(parsing: text)
        var blocks: [Block] = []

        for child in document.children {
            guard let markup = child as? BlockMarkup, let range = child.range else { continue }
            let startLine = range.lowerBound.line - 1
            var endLine = max(startLine, range.upperBound.line - 1)
            if range.upperBound.column == 1 && endLine > startLine {
                endLine -= 1
            }
            blocks.append(Block(markup: markup, lineRange: startLine..<(endLine + 1)))
        }

        self.blocks = blocks
    }

    // MARK: - Update

    mutating func applyEdit(
        replacing replaceRange: Range<Int>,
        withRegionText regionText: String,
        regionStartLine: Int,
        lineDelta: Int
    ) {
        let parsed = Document(parsing: regionText)

        var newBlocks: [Block] = []
        for child in parsed.children {
            guard let markup = child as? BlockMarkup, let range = child.range else { continue }
            let startLine = range.lowerBound.line - 1 + regionStartLine
            var endLine = range.upperBound.line - 1 + regionStartLine
            // cmark's upperBound extends to the next line (column 1) for trailing newlines.
            // The block actually ends on the previous line.
            if range.upperBound.column == 1 && endLine > startLine {
                endLine -= 1
            }
            newBlocks.append(Block(markup: markup, lineRange: startLine..<(endLine + 1)))
        }

        blocks.replaceSubrange(replaceRange, with: newBlocks)

        // Shift blocks after the splice
        if lineDelta != 0 {
            for i in (replaceRange.lowerBound + newBlocks.count)..<blocks.count {
                blocks[i] = Block(
                    markup: blocks[i].markup,
                    lineRange: blocks[i].lineRange.shifted(by: lineDelta)
                )
            }
        }
    }

    // MARK: - Queries

    /// O(log N) binary search for the block index containing `line`.
    func blockIndex(forLine line: Int) -> Int? {
        var low = 0
        var high = blocks.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let block = blocks[mid]

            if block.lineRange.contains(line) {
                return mid
            } else if line < block.lineRange.lowerBound {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }

        return nil
    }

    /// For blank-line edits: returns adjacent block indices.
    func adjacentIndices(at line: Int) -> (before: Int?, after: Int?) {
        var before: Int?
        var after: Int?

        for (i, block) in blocks.enumerated() {
            if block.lineRange.upperBound <= line {
                before = i
            } else if block.lineRange.lowerBound > line && after == nil {
                after = i
                break
            }
        }

        return (before, after)
    }

    /// Walk one block to find the outermost block token for a specific line.
    func topLineToken(at line: Int) -> MarkdownLineToken? {
        guard let (block, lineOffset) = blockAndOffset(forLine: line) else { return nil }

        var collector = TokenCollector(targetLine: line, lineOffset: lineOffset)
        collector.visit(block.markup)
        return collector.result
    }

    /// Walk one block to find inline tokens at a position (line/column, 0-based).
    func inlineTokens(at position: SourcePosition) -> MarkdownInlineToken {
        walkInline(at: position).tokens
    }

    /// Walk one block to find the source range of an inline formatting node.
    /// Returns the column range on the line (0-based).
    func inlineRange(at position: SourcePosition, token: MarkdownInlineToken) -> Range<Int>? {
        guard let range = walkInline(at: position, findRangeFor: token).foundRange else { return nil }
        return (range.lowerBound.column - 1)..<(range.upperBound.column - 1)
    }

    // MARK: - Private

    private func blockAndOffset(forLine line: Int) -> (Block, Int)? {
        guard let idx = blockIndex(forLine: line) else { return nil }
        let block = blocks[idx]
        let blockStartLine = (block.markup.range?.lowerBound.line ?? 1) - 1
        let lineOffset = block.lineRange.lowerBound - blockStartLine
        return (block, lineOffset)
    }

    private func walkInline(at position: SourcePosition, findRangeFor token: MarkdownInlineToken? = nil) -> InlineWalker {
        guard let (block, lineOffset) = blockAndOffset(forLine: position.line) else {
            return InlineWalker(targetLine: 0, targetColumn: 0)
        }
        var walker = InlineWalker(
            targetLine: position.line + 1 - lineOffset,
            targetColumn: position.column + 1,
            rangeForToken: token
        )
        walker.visit(block.markup)
        return walker
    }
}

// MARK: - BlockIndex + AffectedRegion

extension BlockIndex {

    /// Find the block range and line range affected by an edit at `editLine`.
    func affectedRegion(editLine: Int, lineCount: Int) -> (startLine: Int, endLine: Int, replaceRange: Range<Int>) {
        if let idx = blockIndex(forLine: editLine) {
            let block = blocks[idx]
            return (
                block.lineRange.lowerBound,
                block.lineRange.upperBound - 1,
                idx..<(idx + 1)
            )
        }

        let (before, after) = adjacentIndices(at: editLine)
        let startLine = before.map { blocks[$0].lineRange.lowerBound } ?? editLine
        let endLine = after.map { blocks[$0].lineRange.upperBound - 1 } ?? max(editLine, lineCount - 1)
        let rangeStart = before ?? 0
        let rangeEnd = after.map { $0 + 1 } ?? count

        return (startLine, endLine, rangeStart..<rangeEnd)
    }
}

// MARK: - TokenCollector

private struct TokenCollector: MarkupWalker {
    let targetLine: Int
    let lineOffset: Int
    var result: MarkdownLineToken?

    mutating func visitHeading(_ heading: Heading) {
        if result == nil && coversTarget(heading) {
            result = .heading(level: heading.level)
        }
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if result == nil && coversTarget(paragraph) {
            result = .paragraph
        }
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        if result == nil && coversTarget(codeBlock) {
            result = .codeBlock(language: codeBlock.language, isFenced: true)
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        if result == nil && coversTarget(blockQuote) {
            result = .blockQuote(depth: blockQuote.blockDepth)
        }
        descendInto(blockQuote)
    }

    mutating func visitUnorderedList(_ list: UnorderedList) {
        for item in list.listItems {
            visitListItem(item, isOrdered: false, number: nil)
        }
        descendInto(list)
    }

    mutating func visitOrderedList(_ list: OrderedList) {
        var number = Int(list.startIndex)
        for item in list.listItems {
            visitListItem(item, isOrdered: true, number: number)
            number += 1
        }
        descendInto(list)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        if result == nil && coversTarget(thematicBreak) {
            result = .thematicBreak
        }
    }

    mutating func visitTable(_ table: Table) {
        if result == nil && coversTarget(table) {
            result = .table
        }
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        if result == nil && coversTarget(html) {
            result = .htmlBlock
        }
    }

    private mutating func visitListItem(_ item: ListItem, isOrdered: Bool, number: Int?) {
        guard let range = item.range else { return }
        let itemLine = range.lowerBound.line - 1 + lineOffset
        guard itemLine == targetLine else { return }

        let checkbox: MarkdownLineToken.ListItemInfo.Checkbox?
        switch item.checkbox {
        case .checked: checkbox = .checked
        case .unchecked: checkbox = .unchecked
        case .none: checkbox = nil
        }

        let itemColumn = range.lowerBound.column - 1
        let contentColumn: Int
        if let firstChild = item.children.first(where: { $0.range != nil }) {
            contentColumn = firstChild.range!.lowerBound.column - 1
        } else {
            contentColumn = range.upperBound.column - 1
        }

        let info = MarkdownLineToken.ListItemInfo(
            isOrdered: isOrdered,
            depth: item.listDepth,
            marker: isOrdered ? "\(number ?? 1)." : "-",
            checkbox: checkbox,
            number: number,
            prefixLength: contentColumn - itemColumn
        )
        result = .listItem(info)
    }

    private func coversTarget(_ markup: Markup) -> Bool {
        guard let range = markup.range else { return false }
        let startLine = range.lowerBound.line - 1 + lineOffset
        let endLine = range.upperBound.line - 1 + lineOffset
        return targetLine >= startLine && targetLine <= endLine
    }
}

// MARK: - Markup Extensions

private extension BlockQuote {
    var blockDepth: Int {
        var depth = 1
        var current: Markup? = parent
        while let p = current {
            if p is BlockQuote { depth += 1 }
            current = p.parent
        }
        return depth
    }
}

private extension ListItem {
    var listDepth: Int {
        var depth = 0
        var current: Markup? = parent
        while let p = current {
            if p is UnorderedList || p is OrderedList { depth += 1 }
            current = p.parent
        }
        return max(0, depth - 1)
    }
}

// MARK: - InlineWalker

private struct InlineWalker: MarkupWalker {
    let targetLine: Int
    let targetColumn: Int
    var tokens: MarkdownInlineToken = []
    var rangeForToken: MarkdownInlineToken?
    var foundRange: SourceRange?

    mutating func visitStrong(_ strong: Strong) {
        collect(.bold, from: strong)
        descendInto(strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        collect(.italic, from: emphasis)
        descendInto(emphasis)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        collect(.strikethrough, from: strikethrough)
        descendInto(strikethrough)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        collect(.inlineCode, from: inlineCode)
    }

    mutating func visitLink(_ link: Link) {
        collect(.link, from: link)
        descendInto(link)
    }

    mutating func visitImage(_ image: Image) {
        collect(.image, from: image)
    }

    private mutating func collect(_ token: MarkdownInlineToken, from markup: Markup) {
        guard containsTarget(markup) else { return }
        tokens.insert(token)
        if let target = rangeForToken, target.contains(token) {
            foundRange = markup.range
        }
    }

    private func containsTarget(_ markup: Markup) -> Bool {
        guard let range = markup.range else { return false }
        let start = range.lowerBound
        let end = range.upperBound
        if targetLine < start.line || targetLine > end.line { return false }
        if targetLine == start.line && targetColumn < start.column { return false }
        if targetLine == end.line && targetColumn >= end.column { return false }
        return true
    }
}
