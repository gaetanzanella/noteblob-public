import Foundation

// MARK: - InputAdapter

@MainActor
final class InputAdapter: TextInputDelegate {
    private weak var editor: DocumentEditor?

    init(editor: DocumentEditor) {
        self.editor = editor
    }

    func textWillChange(in range: NSRange, replacementString: String) {
        editor?.willChangeText(in: range, replacementString: replacementString)
    }

    func textDidChange() {
        editor?.didChangeText()
    }

    func selectionDidChange() {
        editor?.didChangeSelection()
    }
}
