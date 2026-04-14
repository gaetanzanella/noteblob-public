import Foundation
import Testing

@testable import TextEditorKit

// MARK: - DocumentEditorTests (mocked dependencies)

@Suite
struct DocumentEditorTests {

    // MARK: - Text Change Pipeline

    @Test @MainActor
    func typingTriggersInterceptor() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: nil, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        let input = MockTextInput()
        editor.attach(to: input)
        editor.loadText("Hello")

        input.simulateChange(range: NSRange(location: 5, length: 0), replacement: "!", newText: "Hello!")

        #expect(recorder.interceptedReplacements == ["!"])
    }

    @Test @MainActor
    func interceptorEditGetsApplied() {
        let recorder = CallRecorder()
        let edit = TextEdit(changes: [.replace(range: 5..<6, with: "XX")], selection: 7..<7)
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: edit, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        let input = MockTextInput()
        editor.attach(to: input)
        editor.loadText("Hello")

        input.simulateChange(range: NSRange(location: 5, length: 0), replacement: "!", newText: "Hello!")

        #expect(input._text == "HelloXX")
        #expect(input._selectedRange == NSRange(location: 7, length: 0))
    }

    // MARK: - Actions

    @Test @MainActor
    func applyCallsActivateWhenInactive() {
        let recorder = CallRecorder()
        recorder.isActiveResult = false
        let editor = DocumentEditor(
            interceptors: [], actionHandlerFactory: SpyFactory(recorder: recorder))
        let input = MockTextInput()
        editor.attach(to: input)

        editor.apply(.format(.bold))

        #expect(recorder.activateCalls == 1)
        #expect(recorder.deactivateCalls == 0)
    }

    @Test @MainActor
    func applyCallsDeactivateWhenActive() {
        let recorder = CallRecorder()
        recorder.isActiveResult = true
        let editor = DocumentEditor(
            interceptors: [], actionHandlerFactory: SpyFactory(recorder: recorder))
        let input = MockTextInput()
        editor.attach(to: input)

        editor.apply(.format(.bold))

        #expect(recorder.activateCalls == 0)
        #expect(recorder.deactivateCalls == 1)
    }

    @Test @MainActor
    func isActiveDelegatesToHandler() {
        let recorder = CallRecorder()
        recorder.isActiveResult = true
        let editor = DocumentEditor(
            interceptors: [], actionHandlerFactory: SpyFactory(recorder: recorder))
        let input = MockTextInput()
        editor.attach(to: input)

        #expect(editor.isActive(.format(.bold)))
        recorder.isActiveResult = false
        #expect(!editor.isActive(.format(.bold)))
    }

    // MARK: - Delegate

    @Test @MainActor
    func delegateNotifiedOnTextChange() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: nil, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        editor.delegate = recorder
        let input = MockTextInput()
        editor.attach(to: input)
        editor.loadText("Hello")

        input.simulateChange(range: NSRange(location: 5, length: 0), replacement: "!", newText: "Hello!")

        #expect(recorder.actionStateChanges == 1)
    }

    @Test @MainActor
    func delegateNotifiedOnSelectionChange() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [], actionHandlerFactory: SpyFactory(recorder: recorder))
        editor.delegate = recorder
        let input = MockTextInput()
        editor.attach(to: input)

        editor.didChangeSelection()

        #expect(recorder.actionStateChanges == 1)
    }

    // MARK: - Load & Cancel

    @Test @MainActor
    func loadUpdatesTextInput() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [], actionHandlerFactory: SpyFactory(recorder: recorder))
        let input = MockTextInput()
        editor.attach(to: input)

        editor.loadText("New content")

        #expect(input._text == "New content")
    }

    @Test @MainActor
    func loadBeforeAttachPushesToInput() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [], actionHandlerFactory: SpyFactory(recorder: recorder))

        editor.loadText("Preloaded")

        let input = MockTextInput()
        editor.attach(to: input)

        #expect(input._text == "Preloaded")
    }

    @Test @MainActor
    func cancelEditingRevertsToOriginalText() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: nil, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        let input = MockTextInput()
        editor.attach(to: input)
        editor.loadText("Original")

        input.simulateChange(range: NSRange(location: 8, length: 0), replacement: " modified", newText: "Original modified")

        editor.cancelEditing()
        #expect(input._text == "Original")
    }

    @Test @MainActor
    func cancelEditingDoesNothingWhenEmpty() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [], actionHandlerFactory: SpyFactory(recorder: recorder))
        let input = MockTextInput()
        input._text = "Something"
        editor.attach(to: input)

        editor.cancelEditing()

        #expect(input._text == "Something")
    }

    @Test @MainActor
    func reloadResetsOriginalText() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: nil, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        let input = MockTextInput()
        editor.attach(to: input)

        editor.loadText("Version 1")
        editor.loadText("Version 2")

        input.simulateChange(range: NSRange(location: 9, length: 0), replacement: " edited", newText: "Version 2 edited")

        editor.cancelEditing()
        #expect(input._text == "Version 2")
    }

    // MARK: - UTF-16 / Emoji

    @Test @MainActor
    func emojiUTF16Offsets() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: nil, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        let input = MockTextInput()
        editor.attach(to: input)
        editor.loadText("Hi😀End")

        input.simulateChange(range: NSRange(location: 4, length: 0), replacement: "X", newText: "Hi😀XEnd")

        let ctx = recorder.interceptedContexts[0]
        #expect(ctx.editorContext.selectionOffsets() == 5..<5)
        #expect(ctx.editorContext.currentLineRange() == 0..<8)
    }

    @Test @MainActor
    func typingEmoji() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: nil, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        let input = MockTextInput()
        editor.attach(to: input)
        editor.loadText("AB")

        input.simulateChange(range: NSRange(location: 1, length: 0), replacement: "🌍", newText: "A🌍B")

        let ctx = recorder.interceptedContexts[0]
        #expect(ctx.editorContext.selectionOffsets() == 3..<3)
    }

    @Test @MainActor
    func multilineWithEmoji() {
        let recorder = CallRecorder()
        let editor = DocumentEditor(
            interceptors: [SpyInterceptor(editToReturn: nil, recorder: recorder)],
            actionHandlerFactory: SpyFactory(recorder: recorder)
        )
        let input = MockTextInput()
        editor.attach(to: input)
        editor.loadText("😀\nWorld")

        input.simulateChange(range: NSRange(location: 8, length: 0), replacement: "!", newText: "😀\nWorld!")

        let ctx = recorder.interceptedContexts[0]
        #expect(ctx.editorContext.currentLine == 1)
        #expect(ctx.editorContext.selectionOffsets() == 9..<9)
        #expect(ctx.editorContext.lineRange(at: 1) == 3..<9)
    }

    // MARK: - TextEdit

    @Test
    func insertEdit() {
        let edit = TextEdit(insert: "hello", at: 0)
        #expect(edit.changes.count == 1)
        #expect(edit.selection == 5..<5)
    }

    @Test
    func sortChangesDescending() {
        let changes: [TextEdit.Change] = [
            .insert(at: 0, string: "a"),
            .insert(at: 10, string: "b"),
            .insert(at: 5, string: "c"),
        ]
        let sorted = changes.sortedDescending()
        #expect(sorted[0].offset == 10)
        #expect(sorted[1].offset == 5)
        #expect(sorted[2].offset == 0)
    }
}

// MARK: - Test Helpers

@MainActor
private final class CallRecorder: DocumentEditorDelegate {
    var interceptedReplacements: [String] = []
    var interceptedContexts: [TypeContext] = []
    var activateCalls = 0
    var deactivateCalls = 0
    var isActiveResult = false
    var actionStateChanges = 0

    func documentEditorDidUpdateActions(_ editor: DocumentEditor) {
        actionStateChanges += 1
    }
}

private struct SpyInterceptor: TypeInterceptor {
    let priority = 0
    let editToReturn: TextEdit?
    let recorder: CallRecorder

    func intercept(_ context: TypeContext) -> TextEdit? {
        recorder.interceptedReplacements.append(context.replacementString)
        recorder.interceptedContexts.append(context)
        return editToReturn
    }
}

private struct SpyHandler: DocumentEditorActionHandler {
    let recorder: CallRecorder

    func isActive(in context: EditorContext) -> Bool {
        recorder.isActiveResult
    }

    func activate(in context: EditorContext) -> TextEdit? {
        recorder.activateCalls += 1
        return nil
    }

    func deactivate(in context: EditorContext) -> TextEdit? {
        recorder.deactivateCalls += 1
        return nil
    }
}

private struct SpyFactory: ActionHandlerFactory {
    let recorder: CallRecorder

    func makeHandler(for action: DocumentEditorAction) -> DocumentEditorActionHandler {
        SpyHandler(recorder: recorder)
    }
}
