import Testing
@testable import TextEditorKit

@Suite
struct WrapActionHandlerTests {

    // MARK: - isActive

    @Test @MainActor
    func isActiveInsideBold() {
        let ctx = makeContext("Hello **world** end", cursor: 10)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isNotActiveOutsideBold() {
        let ctx = makeContext("Hello **world** end", cursor: 2)
        let handler = WrapActionHandler(mark: .bold)
        #expect(!handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveInsideItalic() {
        let ctx = makeContext("Hello *world* end", cursor: 8)
        let handler = WrapActionHandler(mark: .italic)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveInsideInlineCode() {
        let ctx = makeContext("Hello `code` end", cursor: 8)
        let handler = WrapActionHandler(mark: .inlineCode)
        #expect(handler.isActive(in: ctx))
    }

    // MARK: - activate

    @Test @MainActor
    func activateWrapsBold() {
        let ctx = makeContext("Hello", cursor: 0, cursorEnd: 5)
        let handler = WrapActionHandler(mark: .bold)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes.count == 2)
        #expect(edit!.changes.contains(.insert(at: 0, string: "**")))
        #expect(edit!.changes.contains(.insert(at: 5, string: "**")))
        #expect(edit!.selection == 2..<7)
    }

    @Test @MainActor
    func activateWrapsItalic() {
        let ctx = makeContext("Hello", cursor: 0, cursorEnd: 5)
        let handler = WrapActionHandler(mark: .italic)
        let edit = handler.activate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.selection == 1..<6)
    }

    // MARK: - deactivate

    @Test @MainActor
    func deactivateRemovesBoldMarkers() {
        let ctx = makeContext("**Hello**", cursor: 2, cursorEnd: 7)
        let handler = WrapActionHandler(mark: .bold)
        let edit = handler.deactivate(in: ctx)

        #expect(edit != nil)
        #expect(edit!.changes.count == 2)
        // Should delete the opening ** and closing **
        #expect(edit!.changes.contains(.delete(0..<2)))
        #expect(edit!.changes.contains(.delete(7..<9)))
        #expect(edit!.selection == 0..<5)
    }

    // MARK: - Collapsed cursor inside formatting

    @Test @MainActor
    func isActiveWithCollapsedCursorInsideBold() {
        // **word** with cursor between the 'o' and 'r' -> should be active
        let ctx = makeContext("**word**", cursor: 4)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveWithEmptyBold() {
        // **** with cursor in the middle (position 2) -> should be active
        let ctx = makeContext("****", cursor: 2)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func deactivateEmptyBold() throws {
        // **** with cursor in the middle -> should remove all markers
        let ctx = makeContext("****", cursor: 2)
        let handler = WrapActionHandler(mark: .bold)
        let edit = try #require(handler.deactivate(in: ctx))

        let result = applyEdit(edit, to: "****")
        #expect(result == "")
        #expect(edit.selection == 0..<0)
    }

    @Test @MainActor
    func isActiveWithEmptyItalic() {
        // ** with cursor in the middle (position 1) -> should be active for italic
        let ctx = makeContext("**", cursor: 1)
        let handler = WrapActionHandler(mark: .italic)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func deactivateEmptyItalic() throws {
        // ** with cursor in the middle -> should remove italic markers
        let ctx = makeContext("**", cursor: 1)
        let handler = WrapActionHandler(mark: .italic)
        let edit = try #require(handler.deactivate(in: ctx))

        let result = applyEdit(edit, to: "**")
        #expect(result == "")
        #expect(edit.selection == 0..<0)
    }

    // MARK: - Inside list items

    @Test @MainActor
    func isActiveInsideBoldOnListItem() {
        // "- hello **world**" — cursor inside **world** at position 12
        let ctx = makeContext("- hello **world**", cursor: 12)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveAtStartOfBoldOnListItem() {
        // Cursor at first letter of bold text (right after the opening **)
        let ctx = makeContext("- hello **world**", cursor: 10, cursorEnd: 15)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func deactivateBoldOnListItem() throws {
        // "- hello **world**" with selection on "world" (range 10..<15)
        let ctx = makeContext("- hello **world**", cursor: 10, cursorEnd: 15)
        let handler = WrapActionHandler(mark: .bold)
        let edit = try #require(handler.deactivate(in: ctx))

        let result = applyEdit(edit, to: "- hello **world**")
        #expect(result == "- hello world")
    }

    // MARK: - Ambiguous wrapper detection

    @Test @MainActor
    func boldIsActiveInsideEmptyBold() {
        // **** with cursor at 2 is empty bold
        let ctx = makeContext("****", cursor: 2)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
    }

    @Test @MainActor
    func italicIsNotActiveInsideBoldContentSelection() {
        // "**bold**" with "bold" selected — italic must NOT report active.
        // The `*` on either side of "bold" are the inner halves of the
        // surrounding `**` markers, not standalone italic delimiters.
        let ctx = makeContext("**bold**", cursor: 2, cursorEnd: 6)
        #expect(!WrapActionHandler(mark: .italic).isActive(in: ctx))
    }

    @Test @MainActor
    func italicIsNotActiveInsideEmptyBold() {
        // "****" cursor at 2 — bold detects the empty wrapper via flanking,
        // so italic must defer to bold and report inactive.
        let ctx = makeContext("****", cursor: 2)
        #expect(!WrapActionHandler(mark: .italic).isActive(in: ctx))
    }

    @Test @MainActor
    func deactivateStripsWrappersWhenSelectionContainsThem() throws {
        // "**bold**" fully selected (markers included, 0..<8). Deactivate
        // must strip the two `**` sitting at the edges of the selection.
        let ctx = makeContext("**bold**", cursor: 0, cursorEnd: 8)
        let handler = WrapActionHandler(mark: .bold)
        let edit = try #require(handler.deactivate(in: ctx))
        let result = applyEdit(edit, to: "**bold**")
        #expect(result == "bold")
    }

    @Test @MainActor
    func isNotActiveForTextBetweenTwoBoldSpans() {
        // "**a**bc**d**" — "bc" sits between two bold spans. The flanking
        // `**` pair are the closing of the first span and the opening of
        // the second, NOT a bold wrapper around "bc". The parser knows
        // "bc" is plain; isActive must trust it.
        let ctx = makeContext("**a**bc**d**", cursor: 5, cursorEnd: 7)
        #expect(!WrapActionHandler(mark: .bold).isActive(in: ctx))
    }

    // MARK: - isEnabled

    @Test @MainActor
    func isEnabledInParagraph() {
        let ctx = makeContext("Hello", cursor: 0)
        #expect(WrapActionHandler(mark: .bold).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isEnabledInHeading() {
        let ctx = makeContext("# Hello", cursor: 2)
        #expect(WrapActionHandler(mark: .bold).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isEnabledInListItem() {
        let ctx = makeContext("- hello", cursor: 2)
        #expect(WrapActionHandler(mark: .italic).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isEnabledInBlockQuote() {
        let ctx = makeContext("> hello", cursor: 2)
        #expect(WrapActionHandler(mark: .bold).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledInsideCodeBlock() {
        // "```\ncode\n```" — cursor on "code" line
        let ctx = makeContext("```\ncode\n```", cursor: 6)
        #expect(!WrapActionHandler(mark: .bold).isEnabled(in: ctx))
        #expect(!WrapActionHandler(mark: .inlineCode).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledOnThematicBreak() {
        // "foo\n\n---" — cursor on "---" line (line 2)
        let ctx = makeContext("foo\n\n---", cursor: 6)
        #expect(!WrapActionHandler(mark: .bold).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledWhenSelectionCrossesParagraphAndCodeBlock() {
        // Selection spans the paragraph line AND the code-block line.
        // "Hello\n\n```\ncode\n```" — select from offset 0 through 12 (into the code block)
        let ctx = makeContext("Hello\n\n```\ncode\n```", cursor: 0, cursorEnd: 12)
        #expect(!WrapActionHandler(mark: .bold).isEnabled(in: ctx))
    }

    @Test @MainActor
    func isDisabledWhenSelectionCrossesParagraphAndHeading() {
        // Even though inline marks are individually allowed in paragraph and
        // heading lines, a selection that spans multiple lines is disabled.
        let ctx = makeContext("# Title\n\nBody", cursor: 2, cursorEnd: 12)
        #expect(!WrapActionHandler(mark: .bold).isEnabled(in: ctx))
    }

    // MARK: - Multi-line / multi-span selections

    @Test @MainActor
    func isDisabledOnMultiLineSelectionAcrossParagraphs() {
        // Inline marks cannot span a paragraph break in markdown —
        // "**alpha\n\nbeta**" does not render as bold. Wrapping a selection
        // that crosses a blank line should therefore be disabled.
        let ctx = makeContext("alpha\n\nbeta", cursor: 0, cursorEnd: 11)
        #expect(!WrapActionHandler(mark: .bold).isEnabled(in: ctx))
    }

    @Test @MainActor
    func deactivateOnPartialSelectionInsideBoldAddsWrappers() throws {
        // "**hello world**" with a selection covering only "world" — a
        // proper subset of the bold content. isActive is true (cursor is
        // inside bold), so apply() routes through deactivate. Deactivate
        // must NOT strip the outer **...**; it should add a fresh pair of
        // wrappers around the selection instead.
        let ctx = makeContext("**hello world**", cursor: 8, cursorEnd: 13)
        let handler = WrapActionHandler(mark: .bold)
        let edit = try #require(handler.deactivate(in: ctx))
        #expect(edit.changes.contains(.insert(at: 8, string: "**")))
        #expect(edit.changes.contains(.insert(at: 13, string: "**")))
        #expect(edit.changes.count == 2)
    }

    @Test @MainActor
    func isActiveForExactBoldContentSelection() {
        // Selection exactly matches the bold content ("hello"): toggle off
        // should remove the surrounding markers, so isActive stays true.
        let ctx = makeContext("**hello**", cursor: 2, cursorEnd: 7)
        #expect(WrapActionHandler(mark: .bold).isActive(in: ctx))
    }

    @Test @MainActor
    func isActiveForSelectionThatCoversBoldNodeIncludingMarkers() {
        // Selection covers the full bold node, markers included — user
        // clearly wants to unbold everything, so this must stay active.
        let ctx = makeContext("**hello**", cursor: 0, cursorEnd: 9)
        #expect(WrapActionHandler(mark: .bold).isActive(in: ctx))
    }

    @Test @MainActor
    func deactivateRemovesInnerBoldInAdjacentBoldSpans() throws {
        // "**fdsqdsq****fdf****dsqfdsq**" — three adjacent bold spans.
        // The middle bold is "**fdf**" (11..<18); selecting just "fdf"
        // (13..<16) is the full content of that middle node, so deactivate
        // should strip those inner markers — not add more wrappers.
        let text = "**fdsqdsq****fdf****dsqfdsq**"
        let ctx = makeContext(text, cursor: 13, cursorEnd: 16)
        let handler = WrapActionHandler(mark: .bold)
        #expect(handler.isActive(in: ctx))
        let edit = try #require(handler.deactivate(in: ctx))
        let result = applyEdit(edit, to: text)
        #expect(result == "**fdsqdsq**fdf**dsqfdsq**")
    }
}
