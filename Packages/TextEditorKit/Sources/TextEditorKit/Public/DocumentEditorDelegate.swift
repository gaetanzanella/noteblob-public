import Foundation

// MARK: - DocumentEditorDelegate

@MainActor
public protocol DocumentEditorDelegate: AnyObject {
    func documentEditorDidUpdateActions(_ editor: DocumentEditor)
    func documentEditor(
        _ editor: DocumentEditor,
        requestTableEditing request: TableEditingRequest
    )
}
