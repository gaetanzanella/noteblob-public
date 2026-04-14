import Foundation
import NoteBlobKit

// MARK: - Navigation

public struct AuthenticateNavigationPayload: Identifiable {
    public let id = UUID()
    public let onAuthenticated: @MainActor () -> Void

    public init(onAuthenticated: @escaping @MainActor () -> Void) {
        self.onAuthenticated = onAuthenticated
    }
}

public enum AuthViewAction {
    case editToken(String)
    case login
}

public enum AuthRedirection {
    case authenticated
}

// MARK: - ViewModel

struct AuthViewModel {
    let token: String
    let isLoading: Bool
    let errorMessage: String?
    var canLogin: Bool { !token.isEmpty && !isLoading }
}

// MARK: - State

struct AuthState {
    var token = ""
    var isLoading = false
    var errorMessage: String?
}

// MARK: - Presenter

@Observable
@MainActor
public final class AuthPresenter {

    private var state = AuthState()
    private let authService: AuthService
    private let payload: AuthenticateNavigationPayload
    private let onRedirection: (AuthRedirection) -> Void

    public init(
        payload: AuthenticateNavigationPayload,
        authService: AuthService,
        onRedirection: @escaping (AuthRedirection) -> Void
    ) {
        self.payload = payload
        self.authService = authService
        self.onRedirection = onRedirection
    }

    func viewModel() -> AuthViewModel {
        AuthViewModel(
            token: state.token,
            isLoading: state.isLoading,
            errorMessage: state.errorMessage
        )
    }

    public func on(_ action: AuthViewAction) {
        switch action {
        case .editToken(let value):
            state.token = value
        case .login:
            Task { await login() }
        }
    }

    private func login() async {
        guard !state.token.isEmpty else { return }
        state.isLoading = true
        state.errorMessage = nil
        do {
            _ = try await authService.login(token: state.token)
            state.token = ""
            payload.onAuthenticated()
            onRedirection(.authenticated)
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isLoading = false
    }
}
