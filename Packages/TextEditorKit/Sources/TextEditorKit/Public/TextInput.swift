import Foundation

// MARK: - TextInputDelegate

/// Delegate protocol for text input events
@MainActor
public protocol TextInputDelegate: AnyObject {

    /// Called before text changes (e.g., UITextView's shouldChangeTextIn)
    func textWillChange(in range: NSRange, replacementString: String)

    /// Called after text changed (e.g., UITextView's textViewDidChange)
    func textDidChange()

    /// Called when selection changes
    func selectionDidChange()
}

// MARK: - TextInput

/// Protocol for text input integration (UITextView, NSTextView wrappers)
@MainActor
public protocol TextInput: AnyObject {

    // MARK: - Delegate

    /// The delegate to notify of text and selection changes
    var delegate: TextInputDelegate? { get set }

    // MARK: - Read

    /// Current plain text content
    func text() -> String

    /// Current selection range
    func selectedRange() -> NSRange

    // MARK: - Write

    /// Set the entire text content
    func setText(_ text: String)

    /// Set the selection range
    func setSelectedRange(_ range: NSRange)

    /// Replace characters in range (used for edits)
    func replaceCharacters(in range: NSRange, with string: String)
}
