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
    private var lastSelectedNote: NoteNavigationPayload?

    // MARK: - Init

    public init(mode: Mode = .threeColumn) {
        self.mode = mode
    }

    // MARK: - Computed

    public var currentFolder: FolderNavigationPayload? {
        contentPath.last?.folderPayload ?? selectedFolder
    }

    public var selectedNote: NoteNavigationPayload? {
        lastSelectedNote
    }

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
        lastSelectedNote = nil
    }

    // MARK: - Selection

    public func selectedItem(for folderPath: RelativePath) -> String? {
        if let id = itemSelections[folderPath] {
            return id
        }
        if mode == .threeColumn, lastSelectedNote?.path.parent == folderPath {
            return lastSelectedNote?.path.value
        }
        return nil
    }

    public func selectNote(_ note: NoteNavigationPayload) {
        itemSelections[note.path.parent] = note.path.value
        lastSelectedNote = note
    }

    public func deselectItem(in folderPath: RelativePath) {
        itemSelections[folderPath] = nil
        if mode == .stack, lastSelectedNote?.path.parent == folderPath {
            lastSelectedNote = nil
        }
    }

    public func deselectNote() {
        if let note = lastSelectedNote {
            itemSelections[note.path.parent] = nil
        }
        lastSelectedNote = nil
    }

    // MARK: - Deep link

    public func deeplinkToFolder(_ folder: FolderNavigationPayload) {
        guard let root = selectedFolder else { return }
        contentPath = []
        itemSelections = [:]
        lastSelectedNote = nil
        for ancestor in folder.path.ancestors() {
            let payload = FolderNavigationPayload(folder: root.folder, path: ancestor)
            contentPath.append(ContentPage.folder(payload))
        }
        contentPath.append(ContentPage.folder(folder))
    }

    public func deeplinkToNote(_ note: NoteNavigationPayload) {
        guard let root = selectedFolder else { return }
        contentPath = []
        itemSelections = [:]
        for ancestor in note.path.ancestors() {
            let payload = FolderNavigationPayload(folder: root.folder, path: ancestor)
            contentPath.append(ContentPage.folder(payload))
        }
        itemSelections[note.path.parent] = note.path.value
        lastSelectedNote = note
    }
}
