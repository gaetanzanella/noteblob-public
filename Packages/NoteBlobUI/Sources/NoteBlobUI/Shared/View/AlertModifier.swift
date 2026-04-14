import SwiftUI

extension View {
    func alert(_ viewModel: AlertViewModel?, onDismiss: @escaping () -> Void) -> some View {
        self.alert(
            viewModel?.title ?? "",
            isPresented: Binding(
                get: { viewModel != nil },
                set: { if !$0 { onDismiss() } }
            )
        ) {
            if let actions = viewModel?.actions {
                ForEach(actions) { action in
                    Button(action.title, role: action.role.buttonRole) {
                        action.handler.trigger()
                    }
                }
            }
        } message: {
            if let message = viewModel?.message {
                Text(message)
            }
        }
    }
}

private extension ActionViewModel.Role {
    var buttonRole: ButtonRole? {
        switch self {
        case .none: nil
        case .destructive: .destructive
        case .cancel: .cancel
        }
    }
}
