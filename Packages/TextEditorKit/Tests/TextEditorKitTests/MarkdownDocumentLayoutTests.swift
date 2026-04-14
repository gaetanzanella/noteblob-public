import Testing

@testable import TextEditorKit

@Suite
struct MarkdownDocumentLayoutTests {

    // MARK: - Parsing

    @Test @MainActor
    func parsesHeading() {
        let layout = MarkdownDocumentLayout()
        layout.setText("## Hello")
        #expect(layout.lineToken(at: 0) == .heading(level: 2))
    }

    @Test @MainActor
    func parsesMultipleBlocks() {
        let layout = MarkdownDocumentLayout()
        layout.setText("# Title\n\nSome text\n\n- item")

        #expect(layout.lineToken(at: 0) == .heading(level: 1))
        #expect(layout.lineToken(at: 2) == .paragraph)
        if case .listItem = layout.lineToken(at: 4) {
        } else {
            Issue.record("Expected listItem at line 4")
        }
    }

    @Test @MainActor
    func parsesCodeBlock() {
        let layout = MarkdownDocumentLayout()
        layout.setText("```swift\nlet x = 1\n```")

        if case .codeBlock(let lang, _) = layout.lineToken(at: 0) {
            #expect(lang == "swift")
        } else {
            Issue.record("Expected codeBlock at line 0")
        }
    }

    @Test @MainActor
    func emptyTextReturnsNil() {
        let layout = MarkdownDocumentLayout()
        layout.setText("")
        #expect(layout.lineToken(at: 0) == nil)
    }

    @Test @MainActor
    func blankLineInsideCodeBlock() {
        let layout = MarkdownDocumentLayout()
        layout.setText("```\nline1\n\nline2\n```")

        if case .codeBlock = layout.lineToken(at: 2) {
        } else {
            Issue.record("Expected codeBlock at line 2 (blank line inside fence)")
        }
    }

    // MARK: - Incremental Update

    @Test @MainActor
    func updateInsideBlock() {
        let layout = MarkdownDocumentLayout()
        layout.setText("## Hello\n\nWorld")

        layout.update(newText: "## Hi\n\nWorld", changedRange: 3..<8, replacementLength: 2)

        #expect(layout.lineToken(at: 0) == .heading(level: 2))
        #expect(layout.lineToken(at: 2) == .paragraph)
    }

    @Test @MainActor
    func updateChangesBlockType() {
        let layout = MarkdownDocumentLayout()
        layout.setText("Hello")

        layout.update(newText: "## Hello", changedRange: 0..<0, replacementLength: 3)

        #expect(layout.lineToken(at: 0) == .heading(level: 2))
    }

    @Test @MainActor
    func updatePreservesOtherBlocks() {
        let layout = MarkdownDocumentLayout()
        layout.setText("# Title\n\n- item\n\nEnd")

        layout.update(
            newText: "# Title\n\n- task\n\nEnd", changedRange: 11..<15, replacementLength: 4)

        #expect(layout.lineToken(at: 0) == .heading(level: 1))
        if case .listItem = layout.lineToken(at: 2) {
        } else {
            Issue.record("Expected listItem at line 2")
        }
        #expect(layout.lineToken(at: 4) == .paragraph)
    }

    @Test @MainActor
    func insertNewlineBetweenBlocks() {
        let layout = MarkdownDocumentLayout()
        layout.setText("# Title\n\nText")

        layout.update(newText: "# Title\n\n\nText", changedRange: 9..<9, replacementLength: 1)

        #expect(layout.lineToken(at: 0) == .heading(level: 1))
        #expect(layout.lineToken(at: 3) == .paragraph)
    }

    @Test @MainActor
    func newlineAtEndOfListDoesNotExtendBlock() {
        let layout = MarkdownDocumentLayout()
        layout.setText("# Title\n\nParagraph\n\n- Hello")

        let insertAt = "# Title\n\nParagraph\n\n- Hello".utf16.count
        layout.update(
            newText: "# Title\n\nParagraph\n\n- Hello\n", changedRange: insertAt..<insertAt,
            replacementLength: 1)

        if case .listItem = layout.lineToken(at: 4) {
        } else {
            Issue.record("Expected listItem at line 4")
        }
        if case .listItem = layout.lineToken(at: 5) {
            Issue.record("Line 5 should not be listItem")
        }
    }

    // MARK: - Insert/Delete Cycles

    @Test @MainActor
    func addThenDeleteListItem() {
        let layout = MarkdownDocumentLayout()
        layout.setText("- Hello")

        layout.update(newText: "- Hello\n- ", changedRange: 7..<7, replacementLength: 3)
        layout.update(newText: "- Hello", changedRange: 7..<10, replacementLength: 0)

        if case .listItem = layout.lineToken(at: 0) {
        } else {
            Issue.record("Expected listItem at line 0 after cycle")
        }
    }

    @Test @MainActor
    func twoListItemsInsertDeleteCycle() {
        let layout = MarkdownDocumentLayout()
        layout.setText("- First\n- Second")

        layout.update(newText: "- First\n- Second\n", changedRange: 16..<16, replacementLength: 1)
        layout.setText("- First\n- Second\n- ")
        layout.update(newText: "- First\n- Second\n", changedRange: 17..<19, replacementLength: 0)
        layout.update(newText: "- First\n- Second", changedRange: 16..<17, replacementLength: 0)

        if case .listItem = layout.lineToken(at: 1) {
        } else {
            Issue.record("Expected listItem at line 1")
        }
        #expect(layout.lineCount == 2)
    }

    @Test @MainActor
    func pasteAtBlankLineBeforeFirstBlock() {
        let layout = MarkdownDocumentLayout()
        // Blank line followed by a heading — line 0 is a gap before the first block
        layout.setText("\n# Title\n\nSome text")

        // Simulate pasting text that replaces the blank line
        layout.update(
            newText: "Pasted content here\n# Title\n\nSome text",
            changedRange: 0..<0,
            replacementLength: 19
        )

        #expect(layout.lineToken(at: 0) == .paragraph)
        #expect(layout.lineToken(at: 1) == .heading(level: 1))
    }

    // MARK: - Coordinates

    @Test @MainActor
    func sourcePositionRoundtrip() {
        let layout = MarkdownDocumentLayout()
        layout.setText("Hello\nWorld")

        let pos = layout.sourcePosition(at: 8)
        #expect(pos.line == 1)
        #expect(pos.column == 2)
        #expect(layout.offset(of: pos) == 8)
    }

    @Test @MainActor
    func lineRangeReturnsCorrectOffsets() {
        let layout = MarkdownDocumentLayout()
        layout.setText("Hello\nWorld")

        #expect(layout.lineRange(at: 0) == 0..<5)
        #expect(layout.lineRange(at: 1) == 6..<11)
    }

    @Test @MainActor
    func lineCount() {
        let layout = MarkdownDocumentLayout()
        layout.setText("A\nB\nC")
        #expect(layout.lineCount == 3)
    }

    // MARK: - Inline Tokens

    @Test @MainActor
    func inlineTokensDetectsBold() {
        let layout = MarkdownDocumentLayout()
        layout.setText("Hello **world** end")

        let tokens = layout.inlineTokens(at: SourcePosition(line: 0, column: 10))
        #expect(tokens.contains(.bold))
    }

    @Test @MainActor
    func inlineTokensEmptyOutsideFormatting() {
        let layout = MarkdownDocumentLayout()
        layout.setText("Hello **world** end")

        let tokens = layout.inlineTokens(at: SourcePosition(line: 0, column: 2))
        #expect(!tokens.contains(.bold))
    }

    @Test @MainActor
    func inlineRangeReturnsBoldNodeRange() {
        let layout = MarkdownDocumentLayout()
        layout.setText("Hello **world** end")

        let range = layout.inlineRange(at: SourcePosition(line: 0, column: 10), token: .bold)
        #expect(range == 6..<15)
    }

    @Test @MainActor
    func inlineRangeReturnsNilOutsideFormatting() {
        let layout = MarkdownDocumentLayout()
        layout.setText("Hello **world** end")

        #expect(layout.inlineRange(at: SourcePosition(line: 0, column: 2), token: .bold) == nil)
    }
}
