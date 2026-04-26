import NoteBlobKit
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct FolderView: View {

    @State var presenter: FolderPresenter
    @State var syncPresenter: SyncPresenter
    let selection: () -> String?

    public init(
        presenter: FolderPresenter, syncPresenter: SyncPresenter,
        selection: @escaping () -> String?
    ) {
        self._presenter = State(initialValue: presenter)
        self._syncPresenter = State(initialValue: syncPresenter)
        self.selection = selection
    }

    @State private var showingNewNote = false
    @State private var showingNewFolder = false
    @State private var renamingRowID: String?
    @State private var renameText = ""

    public var body: some View {
        let vm = presenter.viewModel()
        list(vm: vm)
            #if os(iOS)
            .listStyle(.plain)
            #endif
            .navigationTitle(vm.title)
            .navigationSubtitle(vm.subtitle)
            .toolbar {
                #if os(iOS)
                    if vm.isEditing {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation {
                                    presenter.on(.stopEditing)
                                }
                            } label: {
                                Text("common.done", bundle: .module)
                            }
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Button {
                                presenter.on(.startMove)
                            } label: {
                                Label(
                                    String.localized("folder.move.action"),
                                    systemImage: "folder.badge.gear"
                                )
                            }
                            .disabled(vm.selectedIDs.isEmpty)
                        }
                        ToolbarSpacer(placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) {
                            Button(role: .destructive) {
                                presenter.on(.deleteSelected)
                            } label: {
                                Label(
                                    String.localized("common.delete"),
                                    systemImage: "trash"
                                )
                            }
                            .disabled(vm.selectedIDs.isEmpty)
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button {
                                    showingNewFolder = true
                                } label: {
                                    Label(
                                        String.localized("new_folder.title"),
                                        systemImage: "folder.badge.plus"
                                    )
                                }
                                Button {
                                    withAnimation {
                                        presenter.on(.startEditing)
                                    }
                                } label: {
                                    Label(
                                        String.localized("folder.select.action"),
                                        systemImage: "checkmark.circle"
                                    )
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        ToolbarItem(placement: .bottomBar) {
                            SyncActionView(presenter: syncPresenter)
                        }
                        ToolbarSpacer(placement: .bottomBar)
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) {
                            newNoteMenu(vm: vm)
                        }
                    }
                #else
                ToolbarItem(placement: .automatic) {
                    SyncActionView(presenter: syncPresenter)
                }
                ToolbarSpacer(placement: .automatic)
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingNewFolder = true
                    } label: {
                        Label(
                            String.localized("new_folder.title"),
                            systemImage: "folder.badge.plus"
                        )
                    }
                }
                ToolbarItem(placement: .automatic) {
                    newNoteMenu(vm: vm)
                }
                #endif
            }
            .sheet(isPresented: $showingNewNote) {
                NewNoteSheet(folderName: vm.title) { name in
                    presenter.on(.createNote(name: name))
                }
            }
            .sheet(isPresented: $showingNewFolder) {
                NewFolderSheet(folderName: vm.title) { name in
                    presenter.on(.createFolder(name: name))
                }
            }
            .alert(
                Text("folder.rename.title", bundle: .module),
                isPresented: Binding(
                    get: { renamingRowID != nil },
                    set: { if !$0 { renamingRowID = nil } }
                )
            ) {
                TextField(
                    String.localized("folder.rename.placeholder"),
                    text: $renameText
                )
                Button(String.localized("common.cancel"), role: .cancel) {
                    renamingRowID = nil
                }
                Button(String.localized("folder.rename.action")) {
                    if let id = renamingRowID {
                        presenter.on(.rename(id: id, newName: renameText))
                    }
                    renamingRowID = nil
                }
            } message: {
                Text("folder.rename.message", bundle: .module)
            }
            .alert(vm.alert) { presenter.on(.dismissError) }
            #if os(iOS)
            .environment(\.editMode, Binding(
                get: { vm.isEditing ? .active : .inactive },
                set: { _ in }
            ))
            #endif
            .onAppear {
                presenter.on(.load)
            }
    }

    // MARK: - New Note Menu

    @ViewBuilder
    private func newNoteMenu(vm: FolderViewModel) -> some View {
        if vm.recentNotes.isEmpty {
            Button {
                showingNewNote = true
            } label: {
                Label(
                    String.localized("new_note.title"),
                    systemImage: "square.and.pencil"
                )
            }
        } else {
            Menu {
                Button {
                    showingNewNote = true
                } label: {
                    Label(
                        String.localized("new_note.title"),
                        systemImage: "square.and.pencil"
                    )
                }
                Divider()
                ForEach(vm.recentNotes) { recentNote in
                    Button {
                        presenter.on(.selectRecentNote(recentNote.payload))
                    } label: {
                        Label(recentNote.file.name, systemImage: "doc.text")
                    }
                }
            } label: {
                Label(
                    String.localized("new_note.title"),
                    systemImage: "square.and.pencil"
                )
            }
        }
    }

    // MARK: - List

    private func list(vm: FolderViewModel) -> some View {
        #if os(macOS)
        List(
            selection: Binding<Set<String>>(
                get: { vm.selectedIDs },
                set: { presenter.on(.selectMultiple($0)) }
            )
        ) {
            rows(vm: vm)
        }
        .contextMenu {
            Button {
                showingNewNote = true
            } label: {
                Label(
                    String.localized("new_note.title"),
                    systemImage: "square.and.pencil"
                )
            }
            Button {
                showingNewFolder = true
            } label: {
                Label(
                    String.localized("new_folder.title"),
                    systemImage: "folder.badge.plus"
                )
            }
        }
        #else
        if vm.isEditing {
            List(selection: Binding(
                get: { vm.selectedIDs },
                set: { presenter.on(.selectMultiple($0)) }
            )) {
                rows(vm: vm)
            }
            .dropDestination(for: NoteItemTransfer.self) { items, _ in
                handleDrop(items, toFolderPath: presenter.folderPath)
            }
        } else {
            List(
                selection: Binding<String?>(
                    get: selection,
                    set: { presenter.on(.select($0)) }
                )
            ) {
                rows(vm: vm)
            }
            .dropDestination(for: NoteItemTransfer.self) { items, _ in
                handleDrop(items, toFolderPath: presenter.folderPath)
            }
        }
        #endif
    }

    // MARK: - Drag & Drop

    private func draggablePayload(for row: FolderViewModel.Row, vm: FolderViewModel) -> NoteItemTransfer {
        let items: [NoteItem]
        if vm.selectedIDs.count > 1, vm.selectedIDs.contains(row.id) {
            items = vm.rows.filter { vm.selectedIDs.contains($0.id) }.map { $0.noteItem }
        } else {
            items = [row.noteItem]
        }
        return NoteItemTransfer(folder: presenter.folder, items: items)
    }

    private func copyToPasteboard(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }

    private func handleDrop(_ transfers: [NoteItemTransfer], toFolderPath: RelativePath, operation: DropOperation = .move) -> Bool {
        guard let transfer = transfers.first, !transfer.items.isEmpty else { return false }
        let paths = transfer.items.map(\.path)
        switch operation {
        case .move:
            presenter.on(.moveItemsToFolder(
                paths: paths,
                destinationFolder: transfer.folder,
                destinationPath: toFolderPath
            ))
        case .copy:
            presenter.on(.copyItemsToFolder(
                paths: paths,
                destinationFolder: transfer.folder,
                destinationPath: toFolderPath
            ))
        }
        return true
    }

    @ViewBuilder
    private func rowView(row: FolderViewModel.Row, vm: FolderViewModel) -> some View {
        if row.isFolder {
            FolderDropTargetRow(title: row.name, systemImage: row.systemImage) { items, operation in
                handleDrop(items, toFolderPath: RelativePath(row.id), operation: operation)
            }
            .tag(row.id)
            .draggable(draggablePayload(for: row, vm: vm))
        } else {
            DisclosureRow(title: row.name, systemImage: row.systemImage)
                .tag(row.id)
                .draggable(draggablePayload(for: row, vm: vm))
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func rows(vm: FolderViewModel) -> some View {
        if vm.rows.isEmpty {
            ContentUnavailableView(
                String.localized("folder.empty.title"),
                systemImage: "doc",
                description: Text("folder.empty.description", bundle: .module)
            )
        } else {
            ForEach(vm.rows) { row in
                rowView(row: row, vm: vm)
                    #if os(iOS)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            presenter.on(.delete(row.id))
                        } label: {
                            Label(
                                String.localized("common.delete"),
                                systemImage: "trash"
                            )
                        }
                    }
                    #endif
                    .contextMenu {
                        #if os(macOS)
                        if !row.isFolder {
                            Button {
                                presenter.on(.doubleTap(row.id))
                            } label: {
                                Label(
                                    String.localized("folder.open_in_window.action"),
                                    systemImage: "macwindow"
                                )
                            }
                            Divider()
                        }
                        #endif
                        Button {
                            renameText = row.name
                            renamingRowID = row.id
                        } label: {
                            Label(
                                String.localized("folder.rename.action"),
                                systemImage: "pencil"
                            )
                        }
                        Button {
                            copyToPasteboard(row.id)
                        } label: {
                            Label(
                                String.localized("folder.copy_path.action"),
                                systemImage: "doc.on.doc"
                            )
                        }
                        Button {
                            if vm.selectedIDs.count > 1, vm.selectedIDs.contains(row.id) {
                                presenter.on(.startMove)
                            } else {
                                presenter.on(.startMoveItem(id: row.id))
                            }
                        } label: {
                            Label(
                                String.localized("folder.move.action"),
                                systemImage: "folder.badge.gear"
                            )
                        }
                        Button(role: .destructive) {
                            presenter.on(.delete(row.id))
                        } label: {
                            Label(
                                String.localized("common.delete"),
                                systemImage: "trash"
                            )
                        }
                    }
            }
            .onDelete { indexSet in
                let rows = vm.rows
                for index in indexSet {
                    presenter.on(.delete(rows[index].id))
                }
            }
        }
    }
}
