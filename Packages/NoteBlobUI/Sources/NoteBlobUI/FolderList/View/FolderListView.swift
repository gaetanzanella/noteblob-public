import SwiftUI

public struct FolderListView: View {

    @State var presenter: FolderListPresenter
    let selection: () -> String?

    public init(presenter: FolderListPresenter, selection: @escaping () -> String?) {
        self._presenter = State(initialValue: presenter)
        self.selection = selection
    }

    public var body: some View {
        let vm = presenter.viewModel()
        List(
            selection: Binding<String?>(
                get: selection,
                set: { presenter.on(.select($0)) }
            )
        ) {
            if vm.rows.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("folder_list.empty.title", bundle: .module)
                    } icon: {
                        Image(systemName: "folder.badge.plus")
                    }
                } description: {
                    Text("folder_list.empty.description", bundle: .module)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(vm.rows) { row in
                    DisclosureRow(title: row.name, systemImage: "folder")
                        .contextMenu {
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
        #if os(iOS)
        .listStyle(.plain)
        #endif
        .navigationTitle(Text("folder_list.title", bundle: .module))
        .navigationSubtitle(vm.subtitle)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    presenter.on(.account)
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presenter.on(.addFolder)
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .onAppear { presenter.on(.load) }
    }
}
