import StoreKit
import SwiftUI

public struct NoteView: View {

    @State var presenter: NotePresenter?
    @State var syncPresenter: SyncPresenter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.requestReview) private var requestReview
    @FocusState private var isPreviewFocused: Bool

    private let isFullScreen: Bool
    private let onToggleFullScreen: (() -> Void)?
    private let onSearchAppearanceChange: (Bool) -> Void
    private let hasStackedNotes: Bool
    private let onGoBack: (() -> Void)?

    public init(
        presenter: NotePresenter?,
        syncPresenter: SyncPresenter,
        isFullScreen: Bool,
        onToggleFullScreen: (() -> Void)?,
        onSearchAppearanceChange: @escaping (Bool) -> Void,
        hasStackedNotes: Bool,
        onGoBack: (() -> Void)?
    ) {
        self._presenter = State(initialValue: presenter)
        self._syncPresenter = State(initialValue: syncPresenter)
        self.isFullScreen = isFullScreen
        self.onToggleFullScreen = onToggleFullScreen
        self.onSearchAppearanceChange = onSearchAppearanceChange
        self.hasStackedNotes = hasStackedNotes
        self.onGoBack = onGoBack
    }

    public var body: some View {
        Group {
            if let presenter {
                noteContent(presenter: presenter)
            } else {
                emptyState
            }
        }
        .readableContentMargin()
    }

    // MARK: - Content

    private func noteContent(presenter: NotePresenter) -> some View {
        let vm = presenter.viewModel()
        return Group {
            switch presenter.mode {
            case .editing(let editor):
                NoteEditorView(
                    editor: editor,
                    toolbarActions: vm.toolbarActions,
                    undoRedoActions: vm.undoRedoActions,
                    menuActions: vm.menuActions,
                    actionVersion: presenter.actionVersion,
                    onOpenNoteLink: { presenter.on(.openNoteLink($0)) }
                )
                #if os(iOS)
                    .scrollDismissesKeyboard(.interactively)
                #endif
            case .preview(let content):
                NotePreviewView(
                    content: content,
                    mode: vm.mode.previewMode,
                    onOpenNoteLink: { presenter.on(.openNoteLink($0)) }
                )
                    .focusable()
                    .focusEffectDisabled()
                    .focused($isPreviewFocused)
                    .onKeyPress("e") {
                        presenter.on(.edit)
                        return .handled
                    }
                    .onAppear { isPreviewFocused = true }
            }
        }
        #if os(macOS)
            .safeAreaInset(edge: .top, spacing: 0) {
                LastChangeDateView(date: vm.latestChangeDate)
            }
        #endif
        .navigationTitle(vm.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(vm.mode.isEditing)
            .navigationSubtitle(vm.formattedDate)
        #endif
        .toolbar { toolbarContent(vm: vm, presenter: presenter) }
        #if os(iOS)
            .toolbarBackground(.hidden, for: .bottomBar)
        #endif
        .onAppear { presenter.on(.load) }
        .onChange(of: presenter.shouldRequestReview) { _, shouldRequest in
            if shouldRequest { requestReview() }
        }
        .onChange(of: vm.mode.isEditing) { _, isEditing in
            onSearchAppearanceChange(!isEditing)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("note.select.title", bundle: .module)
            } icon: {
                Image(systemName: "doc.text")
            }
        }
        #if os(macOS)
            .toolbar {
                // Reserves space in the detail toolbar so that the content column's
                // toolbar items don't shift when switching between empty and note states.
                ToolbarSpacer(.fixed, placement: .automatic)
            }
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(vm: NoteViewModel, presenter: NotePresenter) -> some ToolbarContent {
        switch vm.mode {
        case .editing:
            editingToolbar(vm: vm, presenter: presenter)
        case .preview:
            previewToolbar(vm: vm, presenter: presenter)
        }
    }

    @ToolbarContentBuilder
    private func editingToolbar(vm: NoteViewModel, presenter: NotePresenter) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presenter.on(.cancel)
            } label: {
                Text("common.cancel", bundle: .module)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                presenter.on(.stopEditing)
            } label: {
                Text("common.done", bundle: .module)
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        #if os(iOS)
            // iOS editing mode: undo/redo, format actions, and the "more"
            // menu all live in the keyboard accessory bar (InputAccessoryBar).
        #else
            ToolbarItem(placement: .secondaryAction) {
                MacOSToolbarActions(actions: vm.undoRedoActions)
            }
            ToolbarSpacer(.fixed, placement: .secondaryAction)
            ToolbarItem(placement: .secondaryAction) {
                MacOSToolbarActions(actions: vm.toolbarActions)
            }
            if !vm.menuActions.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    editorMenu(actions: vm.menuActions)
                }
            }
        #endif
    }

    @ToolbarContentBuilder
    private func previewToolbar(vm: NoteViewModel, presenter: NotePresenter) -> some ToolbarContent {
        #if os(iOS)
            if horizontalSizeClass == .regular, let onToggleFullScreen {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onToggleFullScreen()
                    } label: {
                        Image(
                            systemName: isFullScreen
                                ? "arrow.down.right.and.arrow.up.left"
                                : "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
            if hasStackedNotes, let onGoBack {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onGoBack) {
                        Label {
                            Text("common.back", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    presenter.on(.edit)
                } label: {
                    Text("note.edit", bundle: .module)
                }
            }
            if horizontalSizeClass == .compact {
                ToolbarItem(placement: .bottomBar) {
                    SyncActionView(presenter: syncPresenter)
                }
            }
            ToolbarSpacer(placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                noteMenu(vm: vm)
            }
        #else
            if hasStackedNotes, let onGoBack {
                ToolbarItem(placement: .automatic) {
                    Button(action: onGoBack) {
                        Label {
                            Text("common.back", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                    .keyboardShortcut("[", modifiers: .command)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    presenter.on(.edit)
                } label: {
                    Text("note.edit", bundle: .module)
                }
            }
            ToolbarItem(placement: .automatic) {
                noteMenu(vm: vm)
            }
        #endif
    }

    // MARK: - Editor Menu

    private func editorMenu(actions: [ToolbarAction]) -> some View {
        Menu {
            ForEach(actions) { action in
                if case .button(let systemImage) = action.kind {
                    Button {
                        action.action()
                    } label: {
                        Label {
                            Text(LocalizedStringKey(action.localizedTitle), bundle: .module)
                        } icon: {
                            Image(systemName: systemImage)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Undo/Redo Menu

    private func undoRedoMenu(actions: [ToolbarAction]) -> some View {
        Menu {
            ForEach(actions) { action in
                if case .button(let systemImage) = action.kind {
                    Button {
                        action.action()
                    } label: {
                        Label {
                            Text(LocalizedStringKey(action.localizedTitle), bundle: .module)
                        } icon: {
                            Image(systemName: systemImage)
                        }
                    }
                    .disabled(!action.isEnabled)
                }
            }
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
    }

    // MARK: - Menu

    private func noteMenu(vm: NoteViewModel) -> some View {
        Menu {
            Button {
                presenter?.on(.toggleRawText)
            } label: {
                switch vm.mode.previewMode {
                case .raw:
                    Label(
                        String.localized("note.menu.show_formatted"),
                        systemImage: "doc.richtext"
                    )
                case .formatted:
                    Label(
                        String.localized("note.menu.show_source"),
                        systemImage: "doc.plaintext"
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
