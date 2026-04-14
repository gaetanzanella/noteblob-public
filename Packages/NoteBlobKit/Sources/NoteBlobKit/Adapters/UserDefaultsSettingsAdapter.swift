import Foundation

final class UserDefaultsSettingsAdapter: SettingsRepository, @unchecked Sendable {

    private enum Keys {
        static let mcpServerEnabled = "mcp.server.enabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isMCPServerEnabled: Bool {
        defaults.bool(forKey: Keys.mcpServerEnabled)
    }

    func setMCPServerEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.mcpServerEnabled)
    }
}
