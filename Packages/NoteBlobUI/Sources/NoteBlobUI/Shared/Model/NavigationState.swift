import Foundation
import NoteBlobKit
import SwiftUI

// MARK: - Content Page

public enum ContentPage: Hashable {
    case folder(FolderNavigationPayload)

    var folderPayload: FolderNavigationPayload? {
        switch self {
        case .folder(let payload): payload
        }
    }
}

// MARK: - Navigation State

@Observable
@MainActor
public final class NavigationState {

    public enum Mode {
        case threeColumn
        case stack
    }

    // MARK: - State

    private let mode: Mode
    public var contentPath: [ContentPage] = []
    private var selectedFolder: FolderNavigationPayload?
    private var itemSelections: [RelativePath: String] = [:]
    /// Linear history of notes visited via inter-note links. `.last` is the
    /// currently displayed note; everything before is navigable via `goBack()`.
    private var noteStack: [NoteNavigationPayload] = []

    // MARK: - Init

    public init(mode: Mode = .threeColumn) {
        self.mode = mode
    }

    // MARK: - Computed

    public var currentFolder: FolderNavigationPayload? {
        contentPath.last?.folderPayload ?? selectedFolder
    }

    public var selectedNote: NoteNavigationPayload? {
        noteStack.last
    }

    public var hasStackedNotes: Bool { noteStack.count >= 2 }

    // MARK: - Sidebar

    public func selectedRootFolder() -> FolderNavigationPayload? {
        selectedFolder
    }

    public func selectRootFolder(_ folder: FolderNavigationPayload?) {
        guard selectedFolder != folder else { return }
        selectedFolder = folder
        resetContent()
    }

    // MARK: - Content

    public func pushFolder(_ folder: FolderNavigationPayload) {
        contentPath.append(ContentPage.folder(folder))
    }

    public func deselectFolder() {
        selectedFolder = nil
        resetContent()
    }

    public func resetContent() {
        contentPath = []
        itemSelections = [:]
        noteStack = []
    }

    // MARK: - Selection

    public func selectedItem(for folderPath: RelativePath) -> String? {
        if let id = itemSelections[folderPath] {
            return id
        }
        if mode == .threeColumn, noteStack.first?.path.parent == folderPath {
            return noteStack.first?.path.value
        }
        return nil
    }

    public func selectNote(_ note: NoteNavigationPayload) {
        itemSelections[note.path.parent] = note.path.value
        noteStack = [note]
    }

    public func deselectItem(in folderPath: RelativePath) {
        itemSelections[folderPath] = nil
        if mode == .stack, selectedNote?.path.parent == folderPath {
            noteStack = []
        }
    }

    public func deselectNote() {
        if let note = selectedNote {
            itemSelections[note.path.parent] = nil
        }
        noteStack = []
    }

    // MARK: - Deep link

    public func deeplinkToFolder(_ folder: FolderNavigationPayload) {
        guard let root = selectedFolder else { return }
        contentPath = []
        itemSelections = [:]
        noteStack = []
        for ancestor in folder.path.ancestors() {
            let payload = FolderNavigationPayload(folder: root.folder, path: ancestor)
            contentPath.append(ContentPage.folder(payload))
        }
        contentPath.append(ContentPage.folder(folder))
    }

    // When `delays` is true, the path/selection mutation is deferred to the
    // next run-loop tick. This is a workaround for a SwiftUI bug on iOS
    // compact NavigationSplitView: triggering a deeplink from the search
    // overlay in the same frame as its dismissal causes the detail column's
    // push to be dropped and spurious `List` selection resets clobber the
    // deeplinked state. Splitting the synchronous clear from the deferred
    // apply lets the overlay dismiss settle before the new state is
    // committed. The caller is responsible for deciding when this is
    // needed — in practice, only when the search is fired from a subfolder
    // view that has to be popped off the content stack.
    public func deeplinkToNote(_ note: NoteNavigationPayload, delays: Bool = false) {
        guard let root = selectedFolder else { return }
        contentPath = []
        itemSelections = [:]
        noteStack = []
        let apply = { [self] in
            for ancestor in note.path.ancestors() {
                let payload = FolderNavigationPayload(folder: root.folder, path: ancestor)
                contentPath.append(ContentPage.folder(payload))
            }
            itemSelections[note.path.parent] = note.path.value
            noteStack = [note]
        }
        if delays {
            DispatchQueue.main.async { apply() }
        } else {
            apply()
        }
    }

    // MARK: - Note Stack

    /// Follows an inter-note link. Only the displayed note changes — the
    /// folder breadcrumb and selection stay anchored to the note at the
    /// bottom of the stack so `goBack()` returns to the same context.
    public func stackNote(_ note: NoteNavigationPayload) {
        guard selectedNote != note else { return }
        noteStack.append(note)
    }

    /// Pops the current note off the stack, revealing the one beneath it.
    /// No-op when nothing's stacked.
    public func unstackNote() {
        guard hasStackedNotes else { return }
        noteStack.removeLast()
    }
}
