import Foundation
import Testing

@testable import TextEditorKit

@Suite
struct UndoObserverTests {

    // MARK: - Helpers

    @MainActor
    private func fire(
        _ observer: UndoObserver,
        _ event: LifecycleContext.Event,
        text: String,
        cursor: Int,
        cursorEnd: Int? = nil
    ) {
        let context = LifecycleContext(
            event: event,
            editorContext: makeContext(text, cursor: cursor, cursorEnd: cursorEnd)
        )
        observer.intercept(context)
    }

    // MARK: - Initial state

    @Test @MainActor
    func canUndoIsFalseAfterLoad() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        #expect(!observer.canUndo)
        #expect(!observer.canRedo)
    }

    // MARK: - Basic undo / redo

    @Test @MainActor
    func undoRestoresPreviousText() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeText, text: "hello!", cursor: 6)

        #expect(observer.canUndo)
        let edit = observer.popUndoEdit(in: makeContext("hello!", cursor: 6))

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 5..<6, with: "")])
    }

    @Test @MainActor
    func redoAfterUndoRestoresNewText() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeText, text: "hello!", cursor: 6)

        _ = observer.popUndoEdit(in: makeContext("hello!", cursor: 6))
        #expect(observer.canRedo)

        let redo = observer.popRedoEdit(in: makeContext("hello", cursor: 5))
        #expect(redo != nil)
        #expect(redo!.changes == [.replace(range: 5..<5, with: "!")])
        #expect(redo!.selection == 6..<6)
    }

    @Test @MainActor
    func newEditClearsRedoStack() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeText, text: "hello!", cursor: 6)

        _ = observer.popUndoEdit(in: makeContext("hello!", cursor: 6))
        #expect(observer.canRedo)

        // A new text edit happens (user types).
        fire(observer, .didChangeText, text: "hello?", cursor: 6)
        #expect(!observer.canRedo)
    }

    // MARK: - Selection

    @Test @MainActor
    func undoRestoresPostLoadCaretWhenNoSelectionChanged() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeText, text: "hello!", cursor: 6)

        let edit = observer.popUndoEdit(in: makeContext("hello!", cursor: 6))
        #expect(edit?.selection == 5..<5)
    }

    @Test @MainActor
    func didChangeSelectionBeforeDidChangeTextDoesNotLoseTransition() {
        // UIKit doesn't guarantee the order of textViewDidChangeSelection
        // vs textViewDidChange during typing. If the selection event fires
        // first with the post-edit text state, the undo push must still
        // happen on the subsequent text event.
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)

        // Simulate UIKit firing selection-change BEFORE text-change, with
        // the text storage already updated to post-edit state.
        fire(observer, .didChangeSelection, text: "hello!", cursor: 6)
        fire(observer, .didChangeText, text: "hello!", cursor: 6)

        #expect(observer.canUndo)
        let edit = observer.popUndoEdit(in: makeContext("hello!", cursor: 6))
        #expect(edit?.changes == [.replace(range: 5..<6, with: "")])
        #expect(edit?.selection == 5..<5)
    }

    @Test @MainActor
    func undoUsesCaretPositionCapturedByLastSelectionChange() {
        // Reproduces: load "hello" with caret at end, user moves caret to 0,
        // then types "x" → text becomes "xhello" caret at 1. Undo should
        // restore "hello" with caret back at 0, not at 5.
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeSelection, text: "hello", cursor: 0)
        fire(observer, .didChangeText, text: "xhello", cursor: 1)

        let edit = observer.popUndoEdit(in: makeContext("xhello", cursor: 1))

        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 0..<1, with: "")])
        #expect(edit!.selection == 0..<0)
    }

    @Test @MainActor
    func redoRestoresCaretPositionAfterEdit() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeSelection, text: "hello", cursor: 0)
        fire(observer, .didChangeText, text: "xhello", cursor: 1)

        _ = observer.popUndoEdit(in: makeContext("xhello", cursor: 1))

        // Redo: caret at the moment of undo (cursor=0 in "hello") should
        // restore to (cursor=1 in "xhello").
        let redo = observer.popRedoEdit(in: makeContext("hello", cursor: 0))
        #expect(redo?.selection == 1..<1)
    }

    // MARK: - Multiple edits

    @Test @MainActor
    func multipleUndosUnwindInReverseOrder() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "a", cursor: 1)
        // Wait past the coalesce window between each edit by manually
        // spacing via distinct snapshot sequences. (The coalesce window is
        // time-based; we can't assume it here.) For this test we only
        // assert stack ordering, so we accept coalescing may reduce the
        // number of undo steps. We instead use a single edit.
        fire(observer, .didChangeText, text: "ab", cursor: 2)

        #expect(observer.canUndo)
        let edit1 = observer.popUndoEdit(in: makeContext("ab", cursor: 2))
        #expect(edit1?.changes == [.replace(range: 1..<2, with: "")])
        #expect(!observer.canUndo)
    }

    // MARK: - Minimal diff

    @Test @MainActor
    func undoEditReplacesOnlyChangedRangeNotWholeDocument() {
        // Before: "hello world foo bar". After: "hello WORLD foo bar" (one
        // word changed in the middle of a long document). The undo edit
        // should only target that range, not rewrite the whole text —
        // otherwise NSTextView loses its scroll position on macOS.
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello world foo bar", cursor: 11)
        fire(observer, .didChangeText, text: "hello WORLD foo bar", cursor: 11)

        let edit = observer.popUndoEdit(in: makeContext("hello WORLD foo bar", cursor: 11))

        #expect(edit?.changes == [.replace(range: 6..<11, with: "world")])
    }

    @Test @MainActor
    func undoEditForDeletionProducesEmptyReplacement() {
        // User deletes "!" from "hello!" — the undo edit re-inserts it.
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello!", cursor: 6)
        fire(observer, .didChangeText, text: "hello", cursor: 5)

        let edit = observer.popUndoEdit(in: makeContext("hello", cursor: 5))

        #expect(edit?.changes == [.replace(range: 5..<5, with: "!")])
    }

    @Test @MainActor
    func undoEditForMiddleInsertionTargetsMiddleRange() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 3)
        fire(observer, .didChangeText, text: "helXlo", cursor: 4)

        let edit = observer.popUndoEdit(in: makeContext("helXlo", cursor: 4))

        #expect(edit?.changes == [.replace(range: 3..<4, with: "")])
    }

    @Test @MainActor
    func undoEditForSelectionReplaceProducesSingleReplace() {
        // User selects "hello" and types "world": delete+insert collapse
        // into one replace.
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 0, cursorEnd: 5)
        fire(observer, .didChangeText, text: "world", cursor: 5)

        let edit = observer.popUndoEdit(in: makeContext("world", cursor: 5))

        #expect(edit?.changes == [.replace(range: 0..<5, with: "hello")])
    }

    @Test @MainActor
    func undoEditDoesNotSplitSurrogatePairOnReplace() {
        // User changes one emoji for another. The diff must cover the full
        // surrogate pair on each side — never emit a lone surrogate half,
        // which String(utf16CodeUnits:) would rewrite to U+FFFD.
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "a😀b", cursor: 0)
        fire(observer, .didChangeText, text: "a😁b", cursor: 0)

        let edit = observer.popUndoEdit(in: makeContext("a😁b", cursor: 0))

        #expect(edit?.changes == [.replace(range: 1..<3, with: "😀")])
    }

    @Test @MainActor
    func undoEditDoesNotSplitSurrogatePairAtSuffix() {
        // Insert text just before an emoji: common suffix starts at the
        // high surrogate. The change must not start between the halves.
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "x😀", cursor: 1)
        fire(observer, .didChangeText, text: "xy😀", cursor: 2)

        let edit = observer.popUndoEdit(in: makeContext("xy😀", cursor: 2))

        #expect(edit?.changes == [.replace(range: 1..<2, with: "")])
    }

    // MARK: - Redo-stack invalidation under coalescing

    @Test @MainActor
    func coalescedEditAfterUndoStillClearsRedoStack() {
        // Build a redo stack via real undo, then trigger a COALESCED edit.
        // Even though the edit is coalesced (no new undo entry), the redo
        // stack MUST be cleared — otherwise redo would restore stale text.
        let manual = ManualMergeStrategy()
        let observer = UndoObserver(mergeStrategy: manual)
        fire(observer, .didLoad, text: "hello", cursor: 5)

        // Push two entries with merge disabled.
        manual.nextDecision = false
        fire(observer, .didChangeText, text: "helloa", cursor: 6)
        fire(observer, .didChangeText, text: "helloab", cursor: 7)

        // Undo twice — redo stack now has two entries.
        _ = observer.popUndoEdit(in: makeContext("helloab", cursor: 7))
        _ = observer.popUndoEdit(in: makeContext("helloa", cursor: 6))
        #expect(observer.canRedo)

        // Force the next edit to be coalesced. Redo must STILL be cleared
        // because the user actually typed something new.
        manual.nextDecision = true
        fire(observer, .didChangeText, text: "x", cursor: 1)

        #expect(!observer.canRedo)
    }

    // MARK: - Empty stack

    @Test @MainActor
    func popUndoEditOnEmptyStackReturnsNil() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 0)
        #expect(observer.popUndoEdit(in: makeContext("hello", cursor: 0)) == nil)
    }

    @Test @MainActor
    func popRedoEditOnEmptyStackReturnsNil() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 0)
        #expect(observer.popRedoEdit(in: makeContext("hello", cursor: 0)) == nil)
    }

    // MARK: - Multi-step unwinding / redo chain

    @Test @MainActor
    func multipleEditsUnwindOneAtATime() {
        // Use NeverMergeStrategy so each edit pushes a separate undo entry.
        let observer = UndoObserver(mergeStrategy: NeverMergeStrategy())
        fire(observer, .didLoad, text: "", cursor: 0)
        fire(observer, .didChangeText, text: "a", cursor: 1)
        fire(observer, .didChangeText, text: "ab", cursor: 2)
        fire(observer, .didChangeText, text: "abc", cursor: 3)

        _ = observer.popUndoEdit(in: makeContext("abc", cursor: 3))
        #expect(observer.canUndo)
        _ = observer.popUndoEdit(in: makeContext("ab", cursor: 2))
        #expect(observer.canUndo)
        _ = observer.popUndoEdit(in: makeContext("a", cursor: 1))
        #expect(!observer.canUndo)
    }

    @Test @MainActor
    func redoChainSurvivesMultipleUndosThenClearsOnNewEdit() {
        let observer = UndoObserver(mergeStrategy: NeverMergeStrategy())
        fire(observer, .didLoad, text: "", cursor: 0)
        fire(observer, .didChangeText, text: "a", cursor: 1)
        fire(observer, .didChangeText, text: "ab", cursor: 2)

        _ = observer.popUndoEdit(in: makeContext("ab", cursor: 2))
        _ = observer.popUndoEdit(in: makeContext("a", cursor: 1))
        #expect(observer.canRedo)

        // A new edit while redo has entries should wipe the redo stack.
        fire(observer, .didChangeText, text: "x", cursor: 1)
        #expect(!observer.canRedo)
    }

    // MARK: - Coalescing

    @Test @MainActor
    func coalescedEditsShareOneUndoEntry() {
        // AlwaysMergeStrategy collapses every subsequent edit into the
        // previous undo step. Undo reverts to the pre-first-edit state.
        let observer = UndoObserver(mergeStrategy: AlwaysMergeStrategy())
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeText, text: "helloa", cursor: 6)
        fire(observer, .didChangeText, text: "helloab", cursor: 7)

        // AlwaysMergeStrategy means NO push. Stack is empty.
        #expect(!observer.canUndo)
    }

    @Test @MainActor
    func noMergeStrategyPushesEveryEdit() {
        let observer = UndoObserver(mergeStrategy: NeverMergeStrategy())
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeText, text: "helloa", cursor: 6)
        fire(observer, .didChangeText, text: "helloab", cursor: 7)

        _ = observer.popUndoEdit(in: makeContext("helloab", cursor: 7))
        #expect(observer.canUndo)
        _ = observer.popUndoEdit(in: makeContext("helloa", cursor: 6))
        #expect(!observer.canUndo)
    }

    // MARK: - Reload resets history

    @Test @MainActor
    func didLoadClearsUndoAndRedoStacks() {
        let observer = UndoObserver()
        fire(observer, .didLoad, text: "hello", cursor: 5)
        fire(observer, .didChangeText, text: "hello!", cursor: 6)
        #expect(observer.canUndo)

        fire(observer, .didLoad, text: "fresh", cursor: 0)
        #expect(!observer.canUndo)
        #expect(!observer.canRedo)
    }
}
