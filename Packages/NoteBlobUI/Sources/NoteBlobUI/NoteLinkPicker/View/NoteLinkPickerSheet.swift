import NoteBlobKit
import SwiftUI

public struct NoteLinkPickerSheet: View {

    @State private var presenter: NoteLinkPickerPresenter
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    public init(presenter: NoteLinkPickerPresenter) {
        self._presenter = State(initialValue: presenter)
    }

    public var body: some View {
        NavigationStack {
            let vm = presenter.viewModel()
            List(
                selection: Binding<String?>(
                    get: { nil },
                    set: { id in
                        guard let id else { return }
                        presenter.on(.select(id))
                    }
                )
            ) {
                if vm.rows.isEmpty, !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(vm.rows) { row in
                        DisclosureRow(
                            title: row.name,
                            subtitle: row.path != .root ? row.path.value : nil,
                            systemImage: "doc.text"
                        )
                        .tag(row.id)
                    }
                }
            }
            #if os(iOS)
                .listStyle(.plain)
            #endif
            .searchable(text: $searchText)
            .navigationTitle(Text("note.link.picker.title", bundle: .module))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
            }
            .onAppear { presenter.on(.search("")) }
            .onChange(of: searchText) { _, newValue in
                presenter.on(.search(newValue))
            }
        }
        #if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
        #endif
    }
}
