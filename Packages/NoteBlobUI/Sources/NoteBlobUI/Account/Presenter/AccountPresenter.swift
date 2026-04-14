import Foundation
import NoteBlobKit
import MCPServerKit

public enum AccountViewAction {
    case logout
    case toggleMCPServer(Bool)
}

public enum AccountRedirection {
    case logout
}

struct AccountViewModel {
    var isAuthenticated: Bool
    var isMCPServerEnabled: Bool
    var mcpServerStatus: MCPServerStatus
}

@Observable
@MainActor
public final class AccountPresenter {

    private struct State {
        var isMCPServerEnabled: Bool
        var mcpServerStatus: MCPServerStatus = .stopped
    }

    private var state: State

    private let authService: AuthService
    private let settingsService: SettingsService
    private let mcpServerController: MCPServerController
    private let onRedirection: (AccountRedirection) -> Void

    public init(
        authService: AuthService,
        settingsService: SettingsService,
        mcpServerController: MCPServerController,
        onRedirection: @escaping (AccountRedirection) -> Void
    ) {
        self.authService = authService
        self.settingsService = settingsService
        self.mcpServerController = mcpServerController
        self.onRedirection = onRedirection
        self.state = State(isMCPServerEnabled: settingsService.isMCPServerEnabled)
    }

    public enum AsyncAction {
        case onAppear
    }

    public func onAsync(_ action: AsyncAction) async {
        switch action {
        case .onAppear:
            state.mcpServerStatus = await mcpServerController.status
            Task {
                for await status in await mcpServerController.statusStream {
                    self.state.mcpServerStatus = status
                }
            }
        }
    }

    func viewModel() -> AccountViewModel {
        AccountViewModel(
            isAuthenticated: authService.isAuthenticated,
            isMCPServerEnabled: state.isMCPServerEnabled,
            mcpServerStatus: state.mcpServerStatus
        )
    }

    public func on(_ action: AccountViewAction) {
        switch action {
        case .logout:
            do {
                try authService.logout()
                onRedirection(.logout)
            } catch {}
        case .toggleMCPServer(let enabled):
            state.isMCPServerEnabled = enabled
            settingsService.setMCPServerEnabled(enabled)
            Task {
                if enabled {
                    do {
                        try await mcpServerController.startHTTPServer(port: 9100)
                    } catch {
                        state.isMCPServerEnabled = false
                        settingsService.setMCPServerEnabled(false)
                    }
                } else {
                    await mcpServerController.stop()
                }
            }
        }
    }
}
