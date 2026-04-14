import SwiftUI

public struct AuthView: View {

    @State var presenter: AuthPresenter

    public init(presenter: AuthPresenter) {
        self._presenter = State(initialValue: presenter)
    }

    public var body: some View {
        let vm = presenter.viewModel()
        VStack(spacing: 24) {
            Spacer()

            Text("auth.title", bundle: .module)
                .font(.largeTitle.bold())

            VStack(spacing: 16) {
                SecureField(text: Binding(
                    get: { vm.token },
                    set: { presenter.on(.editToken($0)) }
                )) {
                    Text("auth.token.placeholder", bundle: .module)
                }
                .textFieldStyle(.roundedBorder)
                .disabled(vm.isLoading)

                Button {
                    presenter.on(.login)
                } label: {
                    Text("auth.sign_in", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canLogin)
            }
            .frame(maxWidth: 300)

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Text("auth.token_hint", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}
