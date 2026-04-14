import Foundation

public final class SettingsService: Sendable {

    private let settingsRepository: SettingsRepository

    init(settingsRepository: SettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    public var isMCPServerEnabled: Bool {
        settingsRepository.isMCPServerEnabled
    }

    public func setMCPServerEnabled(_ enabled: Bool) {
        settingsRepository.setMCPServerEnabled(enabled)
    }
}
