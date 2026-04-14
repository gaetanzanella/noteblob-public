import NoteBlobKit
import NoteBlobUI
import SwiftUI
import QuickLook

// MARK: - Sheet

enum MainSheet: Identifiable {
    case addFolder(AddFolderNavigationPayload)
    case commit(CommitNavigationPayload, onDismiss: @MainActor () -> Void)
    case account
    case movePicker(MoveNavigationPayload)

    var id: String {
        switch self {
        case .addFolder: "addFolder"
        case .commit: "commit"
        case .account: "account"
        case .movePicker: "movePicker"
        }
    }
}

// MARK: - Coordinator

struct MainCoordinator: View {

    let presenterFactory: PresenterFactory
    let onLogout: () -> Void

    @State private var nav = NavigationState.initFromAppStorage()
    @State private var sheet: MainSheet?
    @State private var quickLookURL: URL?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isSearchEnabled = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
        .sheet(item: $sheet) { sheet in
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
            EmptyView()
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
                    }
                }
        }
    }

    @ViewBuilder
    private func detail() -> some View {
        if let folder = nav.selectedRootFolder() {
            let syncPresenter = presenterFactory.makeSyncPresenter(folder: folder.folder) { redirection in
                sheet = .commit(redirection.payload, onDismiss: redirection.onDismiss)
            }
            if let note = nav.selectedNote {
                NoteView(
                    presenter: presenterFactory.makeNotePresenter(payload: note) { redirection in
                        switch redirection {
                        case .dismiss:
                            nav.deselectNote()
                            nav.storeInAppStorage()
                        }
                    },
                    syncPresenter: syncPresenter,
                    isFullScreen: columnVisibility == .detailOnly,
                    onToggleFullScreen: {
                        withAnimation {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    },
                    onSearchAppearanceChange: { isSearchEnabled = $0 }
                )
                .id(note)
            } else {
                NoteView(syncPresenter: syncPresenter, onSearchAppearanceChange: { isSearchEnabled = $0 })
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
        case .commit(let payload, let onDismiss):
            StatusCoordinator(
                presenterFactory: presenterFactory,
                payload: payload,
                onDismiss: {
                    self.sheet = nil
                    onDismiss()
                }
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
                sheet = .commit(redirection.payload, onDismiss: redirection.onDismiss)
            },
            selection: { nav.selectedItem(for: payload.path) }
        )
        .id(payload)
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
                    nav.deeplinkToNote(notePayload)
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
