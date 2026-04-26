import SwiftUI

struct AddFolderMenuView: View {

    @State var presenter: AddFolderMenuPresenter
    let selection: () -> AddFolderPage?
    let onDismiss: @MainActor () -> Void

    var body: some View {
        let vm = presenter.viewModel()
        List(
            selection: Binding<AddFolderMenuViewAction?>(
                get: {
                    switch selection() {
                    case .local: return .selectLocal
                    case .github: return .selectGitHub
                    case .createRepository: return .selectCreateRepository
                    case .branchPicker: return nil
                    case nil: return nil
                    }
                },
                set: { action in
                    guard let action else { return }
                    presenter.on(action)
                }
            )
        ) {
            Section {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("add_folder.menu.local.title", bundle: .module)
                            Text("add_folder.menu.local.description", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "internaldrive")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .tag(AddFolderMenuViewAction.selectLocal)
            }

            Section {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("add_folder.menu.github.title", bundle: .module)
                            Text(
                                vm.isAuthenticated
                                    ? "add_folder.menu.github.description"
                                    : "add_folder.menu.github.needs_auth",
                                bundle: .module
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.down.circle")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .tag(AddFolderMenuViewAction.selectGitHub)
            }

            Section {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("add_folder.menu.create_repository.title", bundle: .module)
                            Text(
                                vm.isAuthenticated
                                    ? "add_folder.menu.create_repository.description"
                                    : "add_folder.menu.create_repository.needs_auth",
                                bundle: .module
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "shippingbox")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .tag(AddFolderMenuViewAction.selectCreateRepository)
            }
        }
        .navigationTitle(Text("add_folder.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { onDismiss() } label: {
                    Text("common.cancel", bundle: .module)
                }
            }
        }
    }
}
