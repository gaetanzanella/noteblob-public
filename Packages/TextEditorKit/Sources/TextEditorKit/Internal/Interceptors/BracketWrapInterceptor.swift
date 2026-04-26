import Foundation

// MARK: - BracketWrapInterceptor

/// When the user types `opening` while text is selected, wraps the selection
/// with `opening` and `closing` instead of replacing it.
struct BracketWrapInterceptor: TypeInterceptor {

    let opening: String
    let closing: String

    var priority: Int { 0 }

    func intercept(_ context: TypeContext) -> TextEdit? {
        guard context.replacementString == opening else { return nil }
        let selected = context.replacedText
        guard !selected.isEmpty else { return nil }

        // UIKit has already replaced the selection with the opening character.
        // Insert `selected + closing` right after it.
        let insertOffset = context.changedRange.lowerBound + opening.utf16.count
        let selectionEnd = insertOffset + selected.utf16.count
        return TextEdit(
            changes: [.insert(at: insertOffset, string: selected + closing)],
            selection: insertOffset..<selectionEnd
        )
    }
}
