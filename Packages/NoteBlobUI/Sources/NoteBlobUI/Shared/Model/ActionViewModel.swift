import Foundation

struct ActionViewModel: Identifiable, Sendable {

    enum Role: Sendable {
        case none
        case destructive
        case cancel
    }

    let id: ViewID
    let title: String
    let role: Role
    let isEnabled: Bool
    let handler: ViewAction<Void>

    static func text(
        id: ViewID = ViewID(),
        _ title: String,
        role: Role = .none,
        isEnabled: Bool = true,
        handler: @MainActor @Sendable @escaping () -> Void
    ) -> ActionViewModel {
        ActionViewModel(
            id: id,
            title: title,
            role: role,
            isEnabled: isEnabled,
            handler: ViewAction(action: handler)
        )
    }
}
