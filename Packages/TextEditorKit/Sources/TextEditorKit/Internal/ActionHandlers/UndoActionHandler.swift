import Foundation

// MARK: - UndoActionHandler

@MainActor
struct UndoActionHandler: DocumentEditorActionHandler {

    let undoObserver: UndoObserver

    func isEnabled(in context: EditorContext) -> Bool {
        undoObserver.canUndo
    }

    func isActive(in context: EditorContext) -> Bool {
        false
    }

    func activate(in context: EditorContext) -> TextEdit? {
        undoObserver.popUndoEdit(in: context)
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        nil
    }
}

// MARK: - RedoActionHandler

@MainActor
struct RedoActionHandler: DocumentEditorActionHandler {

    let undoObserver: UndoObserver

    func isEnabled(in context: EditorContext) -> Bool {
        undoObserver.canRedo
    }

    func isActive(in context: EditorContext) -> Bool {
        false
    }

    func activate(in context: EditorContext) -> TextEdit? {
        undoObserver.popRedoEdit(in: context)
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        nil
    }
}
