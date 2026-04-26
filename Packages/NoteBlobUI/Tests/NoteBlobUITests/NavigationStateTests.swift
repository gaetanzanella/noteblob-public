import Foundation
import Testing
import NoteBlobKit
@testable import NoteBlobUI

@MainActor
struct NavigationStateTests {

    private let folder = Folder(localName: "repo")

    private var rootPayload: FolderNavigationPayload {
        FolderNavigationPayload(folder: folder)
    }

    private func folderPayload(_ path: String) -> FolderNavigationPayload {
        FolderNavigationPayload(folder: folder, path: RelativePath(path))
    }

    private func notePayload(_ path: String) -> NoteNavigationPayload {
        NoteNavigationPayload(folder: folder, path: RelativePath(path))
    }

    // MARK: - Initial state

    @Test(.tags(.threeColumn, .stack))
    func initialStateIsEmpty() {
        let nav = NavigationState()
        #expect(nav.selectedRootFolder() == nil)
        #expect(nav.currentFolder == nil)
        #expect(nav.selectedNote == nil)
    }

    // MARK: - Sidebar

    @Test(.tags(.threeColumn, .stack))
    func selectFolderSetsCurrentFolder() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        #expect(nav.currentFolder == rootPayload)
    }

    // MARK: - Push

    @Test(.tags(.threeColumn, .stack))
    func pushFolderUpdatesCurrentFolder() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let sub = folderPayload("sub")
        nav.pushFolder(sub)
        #expect(nav.currentFolder == sub)
    }

    // MARK: - Note selection

    @Test(.tags(.threeColumn, .stack))
    func selectNoteDerivesSelectedNote() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let note = notePayload("note.md")
        nav.selectNote(note)
        #expect(nav.selectedNote == note)
        #expect(nav.selectedItem(for: .root) == "note.md")
    }

    @Test(.tags(.threeColumn, .stack))
    func selectNoteInSubfolder() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let sub = folderPayload("sub")
        nav.pushFolder(sub)
        let note = notePayload("sub/note.md")
        nav.selectNote(note)
        #expect(nav.selectedNote == note)
        #expect(nav.selectedItem(for: RelativePath("sub")) == "sub/note.md")
    }

    // MARK: - Deselect (threeColumn)

    @Test(.tags(.threeColumn))
    func deselectItemKeepsNoteFallbackInThreeColumn() {
        var nav = NavigationState(mode: .threeColumn)
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.deselectItem(in: .root)
        // selectedItem falls back to lastSelectedNote
        #expect(nav.selectedItem(for: .root) == "note.md")
        #expect(nav.selectedNote == notePayload("note.md"))
    }

    // MARK: - Deselect (stack)

    @Test(.tags(.stack))
    func deselectItemClearsNoteInStack() {
        var nav = NavigationState(mode: .stack)
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.deselectItem(in: .root)
        // selection and note are fully cleared
        #expect(nav.selectedItem(for: .root) == nil)
        #expect(nav.selectedNote == nil)
    }

    @Test(.tags(.stack))
    func deselectItemInUnrelatedFolderDoesNotClearNoteInStack() {
        var nav = NavigationState(mode: .stack)
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.deselectItem(in: RelativePath("other"))
        // note is in root, not "other" — should not clear
        #expect(nav.selectedNote == notePayload("note.md"))
    }

    @Test(.tags(.stack))
    func cancelBackRestoresSelectionInStack() {
        var nav = NavigationState(mode: .stack)
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        // Selection is set via itemSelections
        #expect(nav.selectedItem(for: .root) == "note.md")
        // If back is canceled, deselectItem is never called → selection stays
        #expect(nav.selectedNote == notePayload("note.md"))
    }

    // MARK: - Reset

    @Test(.tags(.threeColumn, .stack))
    func resetContentClearsEverything() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.pushFolder(folderPayload("sub"))
        nav.selectNote(notePayload("sub/note.md"))
        nav.resetContent()
        #expect(nav.currentFolder == rootPayload)
        #expect(nav.selectedNote == nil)
        #expect(nav.selectedItem(for: RelativePath("sub")) == nil)
    }

    @Test(.tags(.threeColumn, .stack))
    func resetContentPreservesSelectedFolder() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.pushFolder(folderPayload("sub"))
        nav.resetContent()
        #expect(nav.selectedRootFolder() == rootPayload)
    }

    // MARK: - Deep link to folder

    @Test(.tags(.threeColumn, .stack))
    func deeplinkToFolderBuildsFullPath() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let target = folderPayload("a/b/c")
        nav.deeplinkToFolder(target)
        #expect(nav.currentFolder == target)
        // No intermediate selections (matches pushFolder behavior)
        #expect(nav.selectedItem(for: .root) == nil)
        #expect(nav.selectedItem(for: RelativePath("a")) == nil)
        #expect(nav.selectedItem(for: RelativePath("a/b")) == nil)
    }

    @Test(.tags(.threeColumn, .stack))
    func deeplinkToFolderAtRootLevel() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let target = folderPayload("docs")
        nav.deeplinkToFolder(target)
        #expect(nav.currentFolder == target)
        // No selection set (matches pushFolder behavior)
        #expect(nav.selectedItem(for: .root) == nil)
    }

    @Test(.tags(.threeColumn))
    func deeplinkToFolderClearsNoteInThreeColumn() {
        var nav = NavigationState(mode: .threeColumn)
        nav.selectRootFolder(rootPayload)
        nav.pushFolder(folderPayload("old"))
        nav.selectNote(notePayload("old/note.md"))
        nav.deeplinkToFolder(folderPayload("new"))
        // deeplinkToFolder clears lastSelectedNote
        #expect(nav.selectedItem(for: RelativePath("old")) == nil)
        #expect(nav.selectedNote == nil)
    }

    @Test(.tags(.stack))
    func deeplinkToFolderClearsNoteInStack() {
        var nav = NavigationState(mode: .stack)
        nav.selectRootFolder(rootPayload)
        nav.pushFolder(folderPayload("old"))
        nav.selectNote(notePayload("old/note.md"))
        nav.deeplinkToFolder(folderPayload("new"))
        // deeplinkToFolder clears everything
        #expect(nav.selectedItem(for: RelativePath("old")) == nil)
        #expect(nav.selectedNote == nil)
    }

    // MARK: - Deep link to note

    @Test(.tags(.threeColumn, .stack))
    func deeplinkToNoteBuildsPathAndSelectsNote() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let note = notePayload("a/b/note.md")
        nav.deeplinkToNote(note)
        #expect(nav.selectedNote == note)
        // Only the note's parent folder has selection (matches pushFolder behavior)
        #expect(nav.selectedItem(for: .root) == nil)
        #expect(nav.selectedItem(for: RelativePath("a")) == nil)
        #expect(nav.selectedItem(for: RelativePath("a/b")) == "a/b/note.md")
    }

    @Test(.tags(.threeColumn, .stack))
    func deeplinkToNoteAtRoot() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let note = notePayload("note.md")
        nav.deeplinkToNote(note)
        #expect(nav.selectedNote == note)
        #expect(nav.selectedItem(for: .root) == "note.md")
    }

    // MARK: - Back navigation (threeColumn)

    @Test(.tags(.threeColumn))
    func pushFolderFallsBackToNoteInThreeColumn() {
        var nav = NavigationState(mode: .threeColumn)
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.pushFolder(folderPayload("sub"))
        // selectedItem falls back to lastSelectedNote
        #expect(nav.selectedItem(for: .root) == "note.md")
        #expect(nav.selectedNote == notePayload("note.md"))
    }

    @Test(.tags(.threeColumn))
    func selectedItemReturnsNoteForItsParentFolderInThreeColumn() {
        var nav = NavigationState(mode: .threeColumn)
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.pushFolder(folderPayload("sub"))
        #expect(nav.selectedItem(for: .root) == "note.md")
    }

    // MARK: - Back navigation (stack)

    @Test(.tags(.stack))
    func pushFolderKeepsSelectionInStack() {
        var nav = NavigationState(mode: .stack)
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.pushFolder(folderPayload("sub"))
        // selection persists (pushFolder doesn't clear selections)
        #expect(nav.selectedItem(for: .root) == "note.md")
        #expect(nav.selectedNote == notePayload("note.md"))
    }

    // MARK: - Back navigation (shared)

    @Test(.tags(.threeColumn, .stack))
    func selectedNotePersistsAfterPushFolder() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        let note = notePayload("note.md")
        nav.selectNote(note)
        nav.pushFolder(folderPayload("sub"))
        #expect(nav.selectedNote == note)
    }

    @Test(.tags(.threeColumn))
    func selectedNotePersistsAfterDeselectItemInThreeColumn() {
        var nav = NavigationState(mode: .threeColumn)
        nav.selectRootFolder(rootPayload)
        let note = notePayload("note.md")
        nav.selectNote(note)
        nav.deselectItem(in: .root)
        #expect(nav.selectedNote == note)
    }

    @Test(.tags(.threeColumn, .stack))
    func selectedItemReturnsNilForUnrelatedFolder() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.pushFolder(folderPayload("sub"))
        #expect(nav.selectedItem(for: RelativePath("sub")) == nil)
    }

    @Test(.tags(.threeColumn, .stack))
    func selectNoteThenNavigateToOtherFolderAndSelectAnotherNote() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.pushFolder(folderPayload("a"))
        nav.selectNote(notePayload("a/note.md"))
        #expect(nav.selectedNote == notePayload("a/note.md"))

        nav.pushFolder(folderPayload("b"))
        nav.selectNote(notePayload("b/note2.md"))
        #expect(nav.selectedNote == notePayload("b/note2.md"))

        // Previous selections persist (pushFolder doesn't clear)
        #expect(nav.selectedItem(for: .root) == nil)
        #expect(nav.selectedItem(for: RelativePath("a")) == "a/note.md")
        #expect(nav.selectedItem(for: RelativePath("b")) == "b/note2.md")
    }

    @Test(.tags(.threeColumn, .stack))
    func selectRootFolderClearsSelectedNote() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        let otherFolder = Folder(localName: "other")
        nav.selectRootFolder(FolderNavigationPayload(folder: otherFolder))
        #expect(nav.selectedNote == nil)
    }

    // MARK: - Restoration

    @Test(.tags(.threeColumn, .stack))
    func selectSameRootFolderDoesNotClearNote() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.selectRootFolder(rootPayload)
        #expect(nav.selectedNote == notePayload("note.md"))
        #expect(nav.selectedItem(for: .root) == "note.md")
    }

    @Test(.tags(.threeColumn, .stack))
    func selectSameRootFolderPreservesDeeplink() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.deeplinkToNote(notePayload("a/b/note.md"))
        nav.selectRootFolder(rootPayload)
        #expect(nav.selectedNote == notePayload("a/b/note.md"))
    }

    @Test(.tags(.threeColumn, .stack))
    func selectDifferentRootFolderClearsNote() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        let otherFolder = Folder(localName: "other")
        nav.selectRootFolder(FolderNavigationPayload(folder: otherFolder))
        #expect(nav.selectedNote == nil)
    }

    @Test(.tags(.threeColumn, .stack))
    func deeplinkWithNoSelectedFolderIsNoOp() {
        var nav = NavigationState()
        nav.deeplinkToFolder(folderPayload("sub"))
        #expect(nav.currentFolder == nil)
        nav.deeplinkToNote(notePayload("note.md"))
        #expect(nav.selectedNote == nil)
    }

    // MARK: - Deselect folder

    @Test(.tags(.threeColumn, .stack))
    func deselectFolderClearsEverything() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.pushFolder(folderPayload("sub"))
        nav.selectNote(notePayload("sub/note.md"))
        nav.deselectFolder()
        #expect(nav.selectedRootFolder() == nil)
        #expect(nav.currentFolder == nil)
        #expect(nav.selectedNote == nil)
    }

    @Test(.tags(.threeColumn, .stack))
    func deselectFolderAfterSelectIsClean() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.deselectFolder()
        #expect(nav.selectedRootFolder() == nil)
        #expect(nav.currentFolder == nil)
    }

    @Test(.tags(.threeColumn, .stack))
    func deselectFolderThenSelectNewFolder() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        nav.deselectFolder()

        let otherFolder = Folder(localName: "other")
        let otherPayload = FolderNavigationPayload(folder: otherFolder)
        nav.selectRootFolder(otherPayload)
        #expect(nav.selectedRootFolder() == otherPayload)
        #expect(nav.currentFolder == otherPayload)
        #expect(nav.selectedNote == nil)
    }

    // MARK: - Note stack (inter-note links)

    @Test(.tags(.threeColumn, .stack))
    func hasStackedNotesFalseInitially() {
        let nav = NavigationState()
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func hasStackedNotesFalseAfterSingleSelect() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("note.md"))
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func stackNoteChangesSelectedNoteAndSetsFlag() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        #expect(nav.selectedNote == notePayload("b.md"))
        #expect(nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func stackNoteLeavesFolderContextOnBottomNote() {
        // Stacking must not rebuild contentPath or rewrite itemSelections —
        // the folder breadcrumb stays anchored to the note at the bottom of
        // the stack so the user returns to the same context on unstack.
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.pushFolder(folderPayload("a"))
        nav.selectNote(notePayload("a/bottom.md"))
        let folderBefore = nav.currentFolder
        let selectionBefore = nav.selectedItem(for: RelativePath("a"))

        nav.stackNote(notePayload("b/top.md"))

        #expect(nav.currentFolder == folderBefore)
        #expect(nav.selectedItem(for: RelativePath("a")) == selectionBefore)
        // The stacked note's folder must not be visually highlighted — the
        // three-column fallback in `selectedItem` anchors on the bottom note,
        // not the displayed (top) one.
        #expect(nav.selectedItem(for: RelativePath("b")) == nil)
    }

    @Test(.tags(.threeColumn, .stack))
    func stackNoteIsNoOpWhenTargetMatchesSelected() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("a.md"))
        #expect(!nav.hasStackedNotes)
        #expect(nav.selectedNote == notePayload("a.md"))
    }

    @Test(.tags(.threeColumn, .stack))
    func stackMultipleNotesBuildsDeepStack() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        nav.stackNote(notePayload("c.md"))
        #expect(nav.selectedNote == notePayload("c.md"))
        #expect(nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func unstackNoteRevealsPreviousNote() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        nav.unstackNote()
        #expect(nav.selectedNote == notePayload("a.md"))
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func unstackNoteUnwindsOneLevelAtATime() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        nav.stackNote(notePayload("c.md"))

        nav.unstackNote()
        #expect(nav.selectedNote == notePayload("b.md"))
        #expect(nav.hasStackedNotes)

        nav.unstackNote()
        #expect(nav.selectedNote == notePayload("a.md"))
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func unstackNoteIsNoOpWhenEmpty() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.unstackNote()
        #expect(nav.selectedNote == nil)
        nav.selectNote(notePayload("a.md"))
        nav.unstackNote()
        #expect(nav.selectedNote == notePayload("a.md"))
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func selectNoteResetsStack() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        nav.selectNote(notePayload("c.md"))
        #expect(nav.selectedNote == notePayload("c.md"))
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func deeplinkToNoteResetsStack() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        nav.deeplinkToNote(notePayload("c/d.md"))
        #expect(nav.selectedNote == notePayload("c/d.md"))
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func deselectNoteClearsStack() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        nav.deselectNote()
        #expect(nav.selectedNote == nil)
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func resetContentClearsStack() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        nav.resetContent()
        #expect(nav.selectedNote == nil)
        #expect(!nav.hasStackedNotes)
    }

    @Test(.tags(.threeColumn, .stack))
    func selectRootFolderChangeClearsStack() {
        var nav = NavigationState()
        nav.selectRootFolder(rootPayload)
        nav.selectNote(notePayload("a.md"))
        nav.stackNote(notePayload("b.md"))
        let otherFolder = Folder(localName: "other")
        nav.selectRootFolder(FolderNavigationPayload(folder: otherFolder))
        #expect(nav.selectedNote == nil)
        #expect(!nav.hasStackedNotes)
    }
}

// MARK: - Tags

extension Tag {
    @Tag static var threeColumn: Self
    @Tag static var stack: Self
}
