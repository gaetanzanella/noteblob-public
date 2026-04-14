import SwiftUI

public struct SearchResultsView: View {

    let presenter: SearchPresenter
    let searchText: String

    public init(presenter: SearchPresenter, searchText: String) {
        self.presenter = presenter
        self.searchText = searchText
    }

    public var body: some View {
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
                        detail: row.snippet,
                        systemImage: row.systemImage
                    )
                    .tag(row.id)
                }
            }
        }
        #if os(iOS)
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
        #endif
        .background(.background)
        .onAppear {
            presenter.on(.search(searchText))
        }
        .onChange(of: searchText) { _, newValue in
            presenter.on(.search(newValue))
        }
    }
}
