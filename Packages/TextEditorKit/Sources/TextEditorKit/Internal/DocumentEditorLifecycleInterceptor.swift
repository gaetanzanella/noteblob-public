import Foundation

// MARK: - DocumentEditorLifecycleInterceptor

@MainActor
protocol DocumentEditorLifecycleInterceptor: AnyObject {
    func intercept(_ context: LifecycleContext)
}

// MARK: - LifecycleContext

struct LifecycleContext {

    enum Event {
        case didLoad
        case didChangeText
        case didChangeSelection
        case didSave
        case didCancelEditing
    }

    let event: Event
    let editorContext: EditorContext
}
