import SwiftUI

struct LocalFolderView: View {

    @State var presenter: AddFolderPresenter
    @FocusState private var isFocused: Bool

    var body: some View {
        let vm = presenter.localViewModel()
        Form {
            Section {
                TextField(text: Binding(
                    get: { vm.name },
                    set: { presenter.on(.editName($0)) }
                )) {
                    Text("add_folder.local.placeholder", bundle: .module)
                }
                .focused($isFocused)
                .onAppear { isFocused = true }
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("add_folder.local.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { presenter.on(.add) } label: {
                    Text("add_folder.add.action", bundle: .module).bold()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!vm.canAdd)
            }
        }
    }
}
