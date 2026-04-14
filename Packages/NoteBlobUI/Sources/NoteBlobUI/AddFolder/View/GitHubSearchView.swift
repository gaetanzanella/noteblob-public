import SwiftUI

struct GitHubSearchView: View {

    @State var presenter: AddFolderPresenter
    @State private var searchText = ""
    #if os(iOS)
    @State private var isSearchActive = false
    #endif

    var body: some View {
        let vm = presenter.githubViewModel()
        #if os(macOS)
        macOSBody(vm: vm)
        #else
        iOSBody(vm: vm)
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    @FocusState private var isFocused: Bool
    private func macOSBody(vm: GitHubSearchViewModel) -> some View {
        VStack(spacing: 12) {
            TextField(text: $searchText) {
                Text("add_folder.search.placeholder", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .focused($isFocused)
            .onAppear { isFocused = true }

            Group {
                switch vm.state {
                case .idle:
                    ContentUnavailableView {
                        Label {
                            Text("add_folder.github.idle.title", bundle: .module)
                        } icon: {
                            Image(systemName: "magnifyingglass")
                        }
                    } description: {
                        Text("add_folder.github.idle.description", bundle: .module)
                    }
                case .searching:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .noResults:
                    ContentUnavailableView.search(text: vm.searchQuery)
                case .results(let rows):
                    resultsList(vm: vm, rows: rows)
                        .listStyle(.bordered(alternatesRowBackgrounds: true))
                }
            }
            .frame(maxHeight: .infinity)

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .scenePadding()
        .onChange(of: searchText) {
            presenter.on(.editSearchQuery(searchText))
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                presenter.on(.search)
            }
        }
        .navigationTitle(Text("add_folder.github.title", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                addButton(vm: vm)
            }
        }
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private func iOSBody(vm: GitHubSearchViewModel) -> some View {
        Group {
            switch vm.state {
            case .idle:
                ContentUnavailableView {
                    Label {
                        Text("add_folder.github.idle.title", bundle: .module)
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                } description: {
                    Text("add_folder.github.idle.description", bundle: .module)
                }
            case .searching:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .noResults:
                ContentUnavailableView.search(text: vm.searchQuery)
            case .results(let rows):
                resultsList(vm: vm, rows: rows)
            }
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchActive,
            prompt: Text("add_folder.search.placeholder", bundle: .module)
        )
        .onChange(of: searchText) {
            presenter.on(.editSearchQuery(searchText))
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                presenter.on(.search)
            }
        }
        .navigationTitle(Text("add_folder.github.title", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                addButton(vm: vm)
            }
        }
    }
    #endif

    // MARK: - Shared

    private func resultsList(vm: GitHubSearchViewModel, rows: [GitHubSearchViewModel.Row]) -> some View {
        List(selection: Binding<String?>(
            get: { vm.selectedResult },
            set: {
                #if os(iOS)
                isSearchActive = false
                #endif
                presenter.on(.selectResult($0))
            }
        )) {
            ForEach(rows) { row in
                HStack {
                    Text(row.id)
                    Spacer()
                    if vm.selectedResult == row.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .fontWeight(.semibold)
                    }
                }
                .tag(row.id)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    private func addButton(vm: GitHubSearchViewModel) -> some View {
        Button { presenter.on(.add) } label: {
            Text("add_folder.add.action", bundle: .module).bold()
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .disabled(!vm.canAdd)
    }
}
