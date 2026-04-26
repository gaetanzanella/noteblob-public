import Foundation

// MARK: - MarkdownContext

/// Provides markdown-specific query methods.
/// Accessed via `context.markdown()` on EditorContext.
@MainActor
struct MarkdownContext {

    // MARK: - Properties

    private let storage: MarkdownDocumentLayout
    private let selection: Range<SourcePosition>

    // MARK: - Init

    init(storage: MarkdownDocumentLayout, selection: Range<SourcePosition>) {
        self.storage = storage
        self.selection = selection
    }

    // MARK: - Token Queries

    /// Returns the token for the current line (line containing selection start)
    func currentTopLineToken() -> MarkdownLineToken? {
        storage.lineToken(at: selection.lowerBound.line)
    }

    /// Returns the token for a specific line number (0-based)
    func topLineToken(at line: Int) -> MarkdownLineToken? {
        storage.lineToken(at: line)
    }

    /// Returns the tokens for every line touched by the selection, from
    /// `selection.lowerBound.line` through `selection.upperBound.line` inclusive.
    func selectionLineTokens() -> [MarkdownLineToken?] {
        let startLine = selection.lowerBound.line
        let endLine = selection.upperBound.line
        guard startLine <= endLine else { return [] }
        return (startLine...endLine).map { storage.lineToken(at: $0) }
    }

    /// Returns inline formatting tokens at the selection start
    func currentInlineTokens() -> MarkdownInlineToken {
        storage.inlineTokens(at: selection.lowerBound)
    }

    /// Returns list item info for the current line if it's a list item
    func currentListItemInfo() -> MarkdownLineToken.ListItemInfo? {
        if case .listItem(let info) = currentTopLineToken() {
            return info
        }
        return nil
    }
}
