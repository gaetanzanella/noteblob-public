import Foundation

// MARK: - UndoObserver

@MainActor
final class UndoObserver: DocumentEditorLifecycleInterceptor {

    // MARK: - Constants

    private static let maxEntries = 200

    // MARK: - Types

    private struct Snapshot: Equatable {
        let text: String
        let selection: Range<Int>
    }

    // MARK: - Properties

    private let mergeStrategy: any UndoMergeStrategy
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var lastSnapshot: Snapshot?

    // MARK: - Init

    init(mergeStrategy: any UndoMergeStrategy = TimeBasedMergeStrategy()) {
        self.mergeStrategy = mergeStrategy
    }

    // MARK: - Public

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func popUndoEdit(in context: EditorContext) -> TextEdit? {
        guard let target = undoStack.popLast() else { return nil }
        let current = makeSnapshot(from: context)
        redoStack.append(current)
        lastSnapshot = target
        mergeStrategy.reset()
        return buildEdit(from: current, to: target)
    }

    func popRedoEdit(in context: EditorContext) -> TextEdit? {
        guard let target = redoStack.popLast() else { return nil }
        let current = makeSnapshot(from: context)
        undoStack.append(current)
        lastSnapshot = target
        mergeStrategy.reset()
        return buildEdit(from: current, to: target)
    }

    // MARK: - DocumentEditorLifecycleInterceptor

    func intercept(_ context: LifecycleContext) {
        switch context.event {
        case .didLoad:
            undoStack.removeAll()
            redoStack.removeAll()
            lastSnapshot = makeSnapshot(from: context.editorContext)
            mergeStrategy.reset()
        case .didChangeText:
            handleTextChange(context: context)
        case .didChangeSelection:
            // Keep lastSnapshot's selection fresh so the next text edit
            // pushes the pre-edit caret position onto the undo stack.
            // BUT only when the text hasn't changed — otherwise we're in
            // the middle of a text edit (UIKit can fire the selection
            // delegate before the text delegate) and overwriting the
            // snapshot here would hide the text transition from
            // `handleTextChange`, causing it to skip the undo push.
            let current = makeSnapshot(from: context.editorContext)
            if lastSnapshot?.text == current.text {
                lastSnapshot = current
            }
        case .didSave, .didCancelEditing:
            break
        }
    }

    // MARK: - Private

    private func handleTextChange(context: LifecycleContext) {
        let current = makeSnapshot(from: context.editorContext)
        defer { lastSnapshot = current }

        guard let previous = lastSnapshot, previous.text != current.text else { return }

        // Any user-driven text change invalidates the redo stack — clear it
        // up front, before we decide whether to coalesce this edit into the
        // previous undo entry. Otherwise a coalesced edit (no new push)
        // would leave stale redo entries pointing to an impossible state.
        redoStack.removeAll()

        if mergeStrategy.shouldMerge() { return }

        undoStack.append(previous)
        if undoStack.count > Self.maxEntries {
            undoStack.removeFirst()
        }
    }

    private func buildEdit(from current: Snapshot, to target: Snapshot) -> TextEdit {
        // Replace only the UTF-16 range that actually differs, not the whole
        // document. Replacing the entire text invalidates NSTextView's
        // layout and resets the scroll position on macOS.
        let oldUnits = Array(current.text.utf16)
        let newUnits = Array(target.text.utf16)

        var prefix = 0
        let maxPrefix = min(oldUnits.count, newUnits.count)
        while prefix < maxPrefix && oldUnits[prefix] == newUnits[prefix] {
            prefix += 1
        }

        var suffix = 0
        let maxSuffix = min(oldUnits.count - prefix, newUnits.count - prefix)
        while suffix < maxSuffix
            && oldUnits[oldUnits.count - 1 - suffix] == newUnits[newUnits.count - 1 - suffix]
        {
            suffix += 1
        }

        // Snap boundaries to code-point boundaries so we never produce a
        // slice that splits a surrogate pair. If the last unit of the
        // common prefix is a high surrogate, back off so the full pair is
        // included in the change. Symmetric for the suffix leading edge.
        if prefix > 0, UTF16.isLeadSurrogate(oldUnits[prefix - 1]) {
            prefix -= 1
        }
        if suffix > 0,
           oldUnits.count - suffix < oldUnits.count,
           UTF16.isTrailSurrogate(oldUnits[oldUnits.count - suffix])
        {
            suffix -= 1
        }

        let oldChangeEnd = oldUnits.count - suffix
        let newChangeEnd = newUnits.count - suffix

        let replacementUnits = Array(newUnits[prefix..<newChangeEnd])
        let replacement = String(utf16CodeUnits: replacementUnits, count: replacementUnits.count)

        let changes: [TextEdit.Change]
        if prefix == oldChangeEnd && replacement.isEmpty {
            changes = []
        } else {
            changes = [.replace(range: prefix..<oldChangeEnd, with: replacement)]
        }

        return TextEdit(changes: changes, selection: target.selection)
    }

    private func makeSnapshot(from context: EditorContext) -> Snapshot {
        Snapshot(
            text: context.currentText,
            selection: context.selectionOffsets()
        )
    }
}
