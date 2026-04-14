import Foundation
import Testing

@testable import NoteBlobKit

struct SettingsServiceTests {

    @Test func mcpServerEnabledDefaultsToFalse() {
        let service = SettingsService(settingsRepository: InMemorySettingsRepository())
        #expect(!service.isMCPServerEnabled)
    }

    @Test func setMCPServerEnabledPersists() {
        let repo = InMemorySettingsRepository()
        let service = SettingsService(settingsRepository: repo)
        service.setMCPServerEnabled(true)
        #expect(service.isMCPServerEnabled)
    }

    @Test func setMCPServerEnabledToggle() {
        let repo = InMemorySettingsRepository()
        let service = SettingsService(settingsRepository: repo)
        service.setMCPServerEnabled(true)
        #expect(service.isMCPServerEnabled)
        service.setMCPServerEnabled(false)
        #expect(!service.isMCPServerEnabled)
    }

    @Test func userDefaultsAdapterRoundTrips() {
        let suiteName = "SettingsServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let adapter = UserDefaultsSettingsAdapter(defaults: defaults)
        #expect(!adapter.isMCPServerEnabled)
        adapter.setMCPServerEnabled(true)
        #expect(adapter.isMCPServerEnabled)
    }
}

private final class InMemorySettingsRepository: SettingsRepository, @unchecked Sendable {
    private var _isMCPServerEnabled = false

    var isMCPServerEnabled: Bool { _isMCPServerEnabled }

    func setMCPServerEnabled(_ enabled: Bool) {
        _isMCPServerEnabled = enabled
    }
}
