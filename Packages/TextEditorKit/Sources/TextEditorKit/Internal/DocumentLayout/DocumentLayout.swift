import Foundation

// MARK: - DocumentLayout

/// Read-only document coordinate mapping.
/// Passed to handlers and interceptors via EditorContext.
@MainActor
public protocol DocumentLayout: AnyObject {
    var lineCount: Int { get }
    func lineRange(at line: Int) -> Range<Int>
    func offset(of position: SourcePosition) -> Int
    func sourcePosition(at offset: Int) -> SourcePosition
}

// MARK: - DocumentLayoutInvalidating

/// Extends DocumentLayout with mutation methods.
/// Only used by DocumentEditor to update the layout on text changes.
@MainActor
protocol DocumentLayoutInvalidating: DocumentLayout {
    func setText(_ newText: String)
    func update(newText: String, changedRange: Range<Int>, replacementLength: Int)
}
