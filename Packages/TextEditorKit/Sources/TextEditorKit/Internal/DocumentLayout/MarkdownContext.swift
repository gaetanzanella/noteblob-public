import Foundation

// MARK: - MarkdownContext

/// Provides markdown-specific query methods.
/// Accessed via `context.markdown()` on EditorContext.
@MainActor
public struct MarkdownContext {

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
    public func currentTopLineToken() -> MarkdownLineToken? {
        storage.lineToken(at: selection.lowerBound.line)
    }

    /// Returns the token for a specific line number (0-based)
    public func topLineToken(at line: Int) -> MarkdownLineToken? {
        storage.lineToken(at: line)
    }

    /// Returns inline formatting tokens at the selection start
    public func currentInlineTokens() -> MarkdownInlineToken {
        storage.inlineTokens(at: selection.lowerBound)
    }

    /// Returns the UTF-16 offset range of an inline formatting node at the selection.
    public func currentInlineRange(for token: MarkdownInlineToken) -> Range<Int>? {
        storage.inlineRange(at: selection.lowerBound, token: token)
    }

    /// Returns list item info for the current line if it's a list item
    public func currentListItemInfo() -> MarkdownLineToken.ListItemInfo? {
        if case .listItem(let info) = currentTopLineToken() {
            return info
        }
        return nil
    }
}
