import Foundation

@testable import TextEditorKit

/// Creates an EditorContext from text and cursor position (UTF-16 offset).
@MainActor
func makeContext(_ text: String, cursor: Int, cursorEnd: Int? = nil) -> EditorContext {
    let storage = MarkdownDocumentLayout()
    storage.setText(text)
    return EditorContext(
        selectionUTF16: cursor..<(cursorEnd ?? cursor),
        text: text,
        documentLayout: storage
    )
}

// MARK: - Apply Edit

func applyEdit(_ edit: TextEdit, to text: String) -> String {
    var result = text
    for change in edit.changes.sortedDescending() {
        switch change {
        case .insert(let at, let string):
            let index = result.index(result.startIndex, offsetBy: at)
            result.insert(contentsOf: string, at: index)
        case .replace(let range, let with):
            let start = result.index(result.startIndex, offsetBy: range.lowerBound)
            let end = result.index(result.startIndex, offsetBy: range.upperBound)
            result.replaceSubrange(start..<end, with: with)
        case .delete(let range):
            let start = result.index(result.startIndex, offsetBy: range.lowerBound)
            let end = result.index(result.startIndex, offsetBy: range.upperBound)
            result.removeSubrange(start..<end)
        }
    }
    return result
}

// MARK: - MockTextInput

@MainActor
final class MockTextInput: TextInput {
    weak var delegate: TextInputDelegate?
    var _text: String = ""
    var _selectedRange: NSRange = NSRange(location: 0, length: 0)

    func text() -> String { _text }
    func selectedRange() -> NSRange { _selectedRange }
    func setText(_ text: String) { _text = text }
    func setSelectedRange(_ range: NSRange) { _selectedRange = range }
    func replaceCharacters(in range: NSRange, with string: String) {
        let start = _text.index(_text.startIndex, offsetBy: range.location)
        let end = _text.index(start, offsetBy: range.length)
        _text.replaceSubrange(start..<end, with: string)
    }

    func simulateChange(range: NSRange, replacement: String, newText: String) {
        delegate?.textWillChange(in: range, replacementString: replacement)
        _text = newText
        _selectedRange = NSRange(location: range.location + replacement.utf16.count, length: 0)
        delegate?.textDidChange()
    }
}
