import Foundation

struct AlertViewModel: Identifiable, Sendable {

    let id = UUID()
    let title: String
    let message: String
    let actions: [ActionViewModel]

    static func error(_ message: String) -> AlertViewModel {
        AlertViewModel(
            title: .localized("common.error"),
            message: message,
            actions: [.text(.localized("common.ok"), handler: {})]
        )
    }
}
