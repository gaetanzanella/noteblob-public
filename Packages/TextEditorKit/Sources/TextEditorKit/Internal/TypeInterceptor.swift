import Foundation

// MARK: - TypeInterceptor

/// Intercepts keyboard input to modify text
/// Runs synchronously during text change
@MainActor
protocol TypeInterceptor {

    /// Lower priority runs first
    var priority: Int { get }

    /// Intercept a text change
    /// - Returns: Edit to apply, or nil to pass to next interceptor
    func intercept(_ context: TypeContext) -> TextEdit?
}

// MARK: - TypeContext

struct TypeContext {
    let replacementString: String
    let editorContext: EditorContext
    let changedRange: Range<Int>
    private let previousText: String
    private let newText: String

    init(
        previousText: String,
        newText: String,
        changedRange: Range<Int>,
        replacementString: String,
        editorContext: EditorContext
    ) {
        self.previousText = previousText
        self.newText = newText
        self.changedRange = changedRange
        self.replacementString = replacementString
        self.editorContext = editorContext
    }

    var isNewline: Bool {
        replacementString == "\n"
    }

    var isTab: Bool {
        replacementString == "\t"
    }

    var isDeletion: Bool {
        replacementString.isEmpty && changedRange.count > 0
    }

    /// Text that was replaced (the originally-selected text before the change).
    /// Empty if nothing was selected.
    var replacedText: String {
        guard changedRange.count > 0 else { return "" }
        let ns = previousText as NSString
        let nsRange = NSRange(location: changedRange.lowerBound, length: changedRange.count)
        guard nsRange.location >= 0, nsRange.location + nsRange.length <= ns.length else { return "" }
        return ns.substring(with: nsRange)
    }
}
