import NoteBlobKit
import SwiftUI
import QuickLook
#if os(iOS)
import UIKit
#endif

// MARK: - Sheet

enum MainSheet: Identifiable {
    case addFolder(AddFolderNavigationPayload)
    case commit(CommitNavigationPayload)
    case account
    case movePicker(MoveNavigationPayload)
    case noteLinkPicker(NoteLinkPickerNavigationPayload)
    case urlLink(URLLinkNavigationPayload)
    case tableEditor(TableEditorNavigationPayload)

    var id: String {
        switch self {
        case .addFolder: "addFolder"
        case .commit: "commit"
        case .account: "account"
        case .movePicker: "movePicker"
        case .noteLinkPicker: "noteLinkPicker"
        case .urlLink: "urlLink"
        case .tableEditor: "tableEditor"
        }
    }
}

// MARK: - Coordinator

struct MainCoordinator: View {

    let presenterFactory: PresenterFactory
    let onLogout: () -> Void

    @State private var nav = NavigationState.initFromAppStorage()
    @State private var sheet: MainSheet?
    /// Fires whenever the active sheet dismisses — programmatically via
    /// `self.sheet = nil`, by the child view, or by a user swipe-down gesture.
    /// Set alongside `sheet` whenever a sheet wants a post-dismiss callback
    /// (e.g. the commit sheet asking `SyncPresenter` to refresh).
    @State private var onSheetDismiss: (() -> Void)?
    @State private var quickLookURL: URL?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var isSearchEnabled = true

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebar()
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
                #endif
        } content: {
            content()
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
                #endif
        } detail: {
            detail()
        }
        .sheet(item: $sheet, onDismiss: {
            onSheetDismiss?()
            onSheetDismiss = nil
        }) { sheet in
            sheetContent(sheet)
        }
        .quickLookPreview($quickLookURL)
    }

    // MARK: - Columns

    private func sidebar() -> some View {
        FolderListView(
            presenter: presenterFactory.makeFolderListPresenter(
                initialFolderID: nav.selectedRootFolder()?.folder.id
            ) { redirection in
                switch redirection {
                case .folder(let payload, _):
                    nav.selectRootFolder(payload)
                    nav.storeInAppStorage()
                case .addFolder(let payload):
                    sheet = .addFolder(payload)
                case .account:
                    sheet = .account
                }
            },
            selection: { nav.selectedRootFolder()?.folder.id }
        )
    }

    @ViewBuilder
    private func content() -> some View {
        if let folder = nav.selectedRootFolder() {
            contentStack(folder: folder)
        } else {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                ContentUnavailableView {
                    Label {
                        Text("content.no_repository.title", bundle: .module)
                    } icon: {
                        Image(systemName: "shippingbox")
                    }
                } description: {
                    Text("content.no_repository.description", bundle: .module)
                }
            } else {
                EmptyView()
            }
            #else
            EmptyView()
            #endif
        }
    }

    private func contentStack(folder: FolderNavigationPayload) -> some View {
        @Bindable var bindableNav = nav
        return NavigationStack(path: $bindableNav.contentPath) {
            folderView(payload: folder)
                .id(folder)
                .navigationDestination(for: ContentPage.self) { page in
                    switch page {
                    case .folder(let payload):
                        folderView(payload: payload)
                            .id(payload)
                    }
                }
        }
    }

    @ViewBuilder
    private func detail() -> some View {
        if let folder = nav.selectedRootFolder() {
            let syncPresenter = presenterFactory.makeSyncPresenter(folder: folder.folder) { redirection in
                onSheetDismiss = redirection.onDismiss
                sheet = .commit(redirection.payload)
            }
            if let note = nav.selectedNote {
                NoteView(
                    presenter: presenterFactory.makeNotePresenter(payload: note) { redirection in
                        switch redirection {
                        case .dismiss:
                            nav.deselectNote()
                            nav.storeInAppStorage()
                        case .openNote(let payload):
                            nav.stackNote(payload)
                            nav.storeInAppStorage()
                        case .pickLinkTarget(let payload):
                            sheet = .noteLinkPicker(payload)
                        case .pickURLTarget(let payload):
                            sheet = .urlLink(payload)
                        case .pickTableTarget(let payload):
                            sheet = .tableEditor(payload)
                        }
                    },
                    syncPresenter: syncPresenter,
                    isFullScreen: columnVisibility == .detailOnly,
                    onToggleFullScreen: {
                        withAnimation {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    },
                    onSearchAppearanceChange: { isSearchEnabled = $0 },
                    hasStackedNotes: nav.hasStackedNotes,
                    onGoBack: {
                        nav.unstackNote()
                        nav.storeInAppStorage()
                    }
                )
                .id(note)
            } else {
                NoteView(
                    presenter: nil,
                    syncPresenter: syncPresenter,
                    isFullScreen: false,
                    onToggleFullScreen: nil,
                    onSearchAppearanceChange: { isSearchEnabled = $0 },
                    hasStackedNotes: false,
                    onGoBack: nil
                )
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Screen Builders

    private func folderView(payload: FolderNavigationPayload) -> some View {
        SearchableFolderContainer(
            payload: payload,
            presenterFactory: presenterFactory,
            nav: nav,
            isSearchEnabled: isSearchEnabled,
            sheet: $sheet,
            onSheetDismiss: $onSheetDismiss,
            quickLookURL: $quickLookURL
        )
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(_ sheet: MainSheet) -> some View {
        switch sheet {
        case .addFolder(let payload):
            AddFolderCoordinator(
                presenterFactory: presenterFactory,
                onDismiss: {
                    payload.onFoldersChanged()
                    self.sheet = nil
                }
            )
        case .commit(let payload):
            StatusCoordinator(
                presenterFactory: presenterFactory,
                payload: payload,
                onDismiss: { self.sheet = nil }
            )
        case .account:
            AccountView(
                presenter: presenterFactory.makeAccountPresenter { redirection in
                    switch redirection {
                    case .logout:
                        self.sheet = nil
                        onLogout()
                    }
                }
            )
        case .movePicker(let payload):
            MoveDestinationSheet(
                presenter: presenterFactory.makeMoveDestinationPresenter(
                    payload: payload,
                    onRedirection: { redirection in
                        switch redirection {
                        case .didMove:
                            payload.onDidMove()
                            self.sheet = nil
                        }
                    }
                )
            )
        case .noteLinkPicker(let payload):
            NoteLinkPickerSheet(
                presenter: presenterFactory.makeNoteLinkPickerPresenter(
                    payload: NoteLinkPickerNavigationPayload(
                        folder: payload.folder,
                        excluding: payload.excluding,
                        onSelected: { path, title in
                            payload.onSelected(path, title)
                            self.sheet = nil
                        }
                    )
                )
            )
        case .urlLink(let payload):
            URLLinkSheet(
                presenter: presenterFactory.makeURLLinkPresenter(
                    payload: URLLinkNavigationPayload(
                        onConfirmed: { title, url in
                            payload.onConfirmed(title, url)
                            self.sheet = nil
                        }
                    )
                )
            )
        case .tableEditor(let payload):
            TableEditorView(
                presenter: presenterFactory.makeTableEditorPresenter(
                    payload: TableEditorNavigationPayload(
                        initialDraft: payload.initialDraft,
                        onConfirmed: { table in
                            payload.onConfirmed(table)
                            self.sheet = nil
                        }
                    )
                )
            )
        }
    }
}

extension NavigationState {

    private struct CodableRepresentation: Codable {
        let selectedFolder: FolderNavigationPayload?
        let selectedNotePath: String?
    }

    private static let storageKey = "nav.state"

    static func initFromAppStorage() -> NavigationState {
        #if os(iOS)
        let mode = NavigationState.Mode.stack
        #else
        let mode = NavigationState.Mode.threeColumn
        #endif
        let state = NavigationState(mode: mode)
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(CodableRepresentation.self, from: data),
              let folder = saved.selectedFolder else {
            return state
        }
        state.selectRootFolder(folder)
        if let notePath = saved.selectedNotePath {
            state.deeplinkToNote(NoteNavigationPayload(folder: folder.folder, path: RelativePath(notePath)))
        }
        return state
    }

    func storeInAppStorage() {
        let representation = CodableRepresentation(
            selectedFolder: selectedRootFolder(),
            selectedNotePath: selectedNote?.path.value
        )
        if let data = try? JSONEncoder().encode(representation) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Searchable Folder Container

private struct SearchableFolderContainer: View {

    let payload: FolderNavigationPayload
    let presenterFactory: PresenterFactory
    var nav: NavigationState
    var isSearchEnabled: Bool
    @Binding var sheet: MainSheet?
    @Binding var onSheetDismiss: (() -> Void)?
    @Binding var quickLookURL: URL?

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var searchText = ""
    @State private var isSearchPresented = false

    var body: some View {
        Group {
            if isSearchEnabled {
                folderContent()
                    .searchable(text: $searchText, isPresented: $isSearchPresented)
            } else {
                folderContent()
            }
        }
        .overlay {
            if isSearchPresented {
                searchOverlay()
            }
        }
    }

    private func folderContent() -> some View {
        FolderView(
            presenter: presenterFactory.makeFolderPresenter(
                payload: payload,
                selection: { nav.selectedItem(for: payload.path) },
                onRedirection: { redirection in
                    switch redirection {
                    case .folder(let folderPayload):
                        nav.pushFolder(folderPayload)
                    case .note(let notePayload):
                        nav.selectNote(notePayload)
                        nav.storeInAppStorage()
                    case .deeplink(let notePayload):
                        nav.deeplinkToNote(notePayload, delays: true)
                        nav.storeInAppStorage()
                    case .doubleTap(let notePayload):
                        #if os(macOS)
                        openWindow(value: notePayload)
                        #endif
                    case .quickLook(let url):
                        quickLookURL = url
                    case .newNote:
                        break
                    case .deselect:
                        guard !isSearchPresented else { return }
                        nav.deselectItem(in: payload.path)
                        nav.storeInAppStorage()
                    case .movePicker(let movePayload):
                        sheet = .movePicker(movePayload)
                    case .folderNotFound:
                        nav.deselectFolder()
                        nav.storeInAppStorage()
                    case .resetContent:
                        nav.resetContent()
                        nav.storeInAppStorage()
                    }
                },
                currentPath: { nav.currentFolder?.path }
            ),
            syncPresenter: presenterFactory.makeSyncPresenter(folder: payload.folder) { redirection in
                onSheetDismiss = redirection.onDismiss
                sheet = .commit(redirection.payload)
            },
            selection: { nav.selectedItem(for: payload.path) }
        )
    }

    private func searchOverlay() -> some View {
        SearchResultsView(
            presenter: presenterFactory.makeSearchPresenter(
                folder: payload.folder
            ) { redirection in
                searchText = ""
                isSearchPresented = false
                switch redirection {
                case .note(let notePayload):
                    // Only defer on iOS, and only when the search was fired
                    // from a subfolder: that's the case where compact
                    // NavigationSplitView's detail push gets dropped if the
                    // state mutation races the overlay dismiss. From the
                    // root there's no stack to rebuild, and macOS doesn't
                    // have this bug at all.
                    #if os(iOS)
                    nav.deeplinkToNote(notePayload, delays: payload.path != .root)
                    #else
                    nav.deeplinkToNote(notePayload)
                    #endif
                case .folder(let folderPayload):
                    nav.deeplinkToFolder(folderPayload)
                case .quickLook(let url):
                    quickLookURL = url
                }
                nav.storeInAppStorage()
            },
            searchText: searchText
        )
    }
}
