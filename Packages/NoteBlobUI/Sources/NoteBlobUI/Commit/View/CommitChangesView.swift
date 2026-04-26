import SwiftUI

struct CommitChangesView: View {

    let vm: CommitViewModel
    let onAction: (CommitViewAction) -> Void
    @Binding var isShowingDiscardConfirmation: Bool

    var body: some View {
        Section {
            TextField(text: Binding(
                get: { vm.commitMessage },
                set: { onAction(.editMessage($0)) }
            ), axis: .vertical) {
                if vm.isGeneratingMessage {
                    Text("commit.message.generating", bundle: .module)
                } else {
                    Text("commit.message.placeholder", bundle: .module)
                }
            }
            .lineLimit(3...6)
            .disabled(vm.isLoading || vm.isGeneratingMessage)
            #if os(macOS)
            .textFieldStyle(.roundedBorder)
            #endif
        } header: {
            Text("commit.message.header", bundle: .module)
        }

        Section {
            CommitChangesRowsView(vm: vm, onAction: onAction)
        } header: {
            Text("commit.changes_count \(vm.rows.count)", bundle: .module)
        }

        Section {
            Button(role: .destructive) {
                isShowingDiscardConfirmation = true
            } label: {
                Text("commit.discard.action", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .disabled(vm.isLoading)
            .confirmationDialog(
                Text("commit.discard.confirm.title", bundle: .module),
                isPresented: $isShowingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    onAction(.discard)
                } label: {
                    Text("commit.discard.confirm.action", bundle: .module)
                }
            } message: {
                Text("commit.discard.confirm.message", bundle: .module)
            }
        }
    }
}
