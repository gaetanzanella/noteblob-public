import SwiftUI

struct CreateRepositoryView: View {

    @State var presenter: CreateRepositoryPresenter
    @FocusState private var isFocused: Bool

    var body: some View {
        let vm = presenter.viewModel()
        Form {
            Section {
                TextField(text: Binding(
                    get: { vm.name },
                    set: { presenter.on(.editName($0)) }
                )) {
                    Text("create_repository.name.placeholder", bundle: .module)
                }
                .focused($isFocused)
                .onAppear { isFocused = true }
                .disabled(!vm.canEdit)
            } footer: {
                Text("create_repository.name.footer", bundle: .module)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { vm.isPrivate },
                    set: { presenter.on(.setPrivate($0)) }
                )) {
                    Text("create_repository.private.title", bundle: .module)
                }
                .disabled(!vm.canEdit)
            } footer: {
                Text("create_repository.private.footer", bundle: .module)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("create_repository.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { presenter.on(.create) } label: {
                    Text("create_repository.create.action", bundle: .module).bold()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!vm.canCreate)
            }
        }
        .alert(vm.alert) {
            presenter.on(.dismissAlert)
        }
    }
}
