import Foundation

// MARK: - DocumentEditorActionHandler

/// Handles a formatting action
@MainActor
protocol DocumentEditorActionHandler {

    /// Check if action should be shown in UI
    func isVisible(in context: EditorContext) -> Bool

    /// Check if action can be performed (not disabled)
    func isEnabled(in context: EditorContext) -> Bool

    /// Check if action is currently active at cursor
    func isActive(in context: EditorContext) -> Bool

    /// Apply the action (when inactive)
    func activate(in context: EditorContext) -> TextEdit?

    /// Remove the action (when active)
    func deactivate(in context: EditorContext) -> TextEdit?
}

// MARK: - Default Implementations

extension DocumentEditorActionHandler {

    func isVisible(in context: EditorContext) -> Bool {
        true
    }

    func isEnabled(in context: EditorContext) -> Bool {
        true
    }
}

// MARK: - ActionHandlerFactory

@MainActor
protocol ActionHandlerFactory {
    func makeHandler(for action: DocumentEditorAction) -> DocumentEditorActionHandler
}
