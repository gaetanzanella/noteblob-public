import Foundation

// MARK: - AutoSaveObserver

@MainActor
final class AutoSaveObserver: DocumentEditorLifecycleInterceptor {

    private var saveTask: Task<Void, Never>?

    // MARK: - DocumentEditorLifecycleInterceptor

    func intercept(_ context: LifecycleContext) {
        guard let url = context.editorContext.documentURL else { return }
        switch context.event {
        case .didChangeText:
            scheduleSave(text: context.editorContext.currentText, to: url)
        case .didSave:
            cancelPendingSave()
            saveSync(text: context.editorContext.currentText, to: url)
        case .didCancelEditing:
            cancelPendingSave()
            saveSync(text: context.editorContext.currentText, to: url)
        case .didLoad, .didChangeSelection:
            break
        }
    }

    // MARK: - Private

    private func scheduleSave(text: String, to url: URL) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func cancelPendingSave() {
        saveTask?.cancel()
        saveTask = nil
    }

    private func saveSync(text: String, to url: URL) {
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
