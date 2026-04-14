import Foundation

// MARK: - DocumentEditorDelegate

@MainActor
public protocol DocumentEditorDelegate: AnyObject {
    func documentEditorDidUpdateActions(_ editor: DocumentEditor)
}
