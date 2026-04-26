import SwiftUI

struct CommitErrorView: View {

    let vm: CommitViewModel
    let onAction: (CommitViewAction) -> Void

    var body: some View {
        if let errorMessage = vm.errorMessage {
            HStack {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                if vm.needsAuth {
                    Button { onAction(.signIn) } label: {
                        Text("auth.sign_in", bundle: .module)
                    }
                    #if os(macOS)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    #endif
                }
            }
            .padding(.bottom, 8)
        }
    }
}
