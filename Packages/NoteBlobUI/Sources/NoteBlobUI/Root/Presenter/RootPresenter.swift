import Foundation
import NoteBlobKit
import MCPServerKit

@Observable
@MainActor
public final class RootPresenter {

    public enum AsyncAction {
        case onAppear
    }

    private let settingsService: SettingsService
    private let mcpServerController: MCPServerController

    public init(
        settingsService: SettingsService,
        mcpServerController: MCPServerController
    ) {
        self.settingsService = settingsService
        self.mcpServerController = mcpServerController
    }

    public func onAsync(_ action: AsyncAction) async {
        switch action {
        case .onAppear:
            #if os(macOS)
            if settingsService.isMCPServerEnabled {
                try? await mcpServerController.startHTTPServer(port: 9100)
            }
            #endif
        }
    }
}
