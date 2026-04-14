import Foundation

protocol SettingsRepository: Sendable {
    var isMCPServerEnabled: Bool { get }
    func setMCPServerEnabled(_ enabled: Bool)
}
