import Foundation

struct RowViewModel: Identifiable, Sendable {

    let id: ViewID
    let title: String
    let systemImage: String
    let action: ViewAction<Void>

    static func row<ID: Hashable & Sendable>(
        id: ID,
        title: String,
        systemImage: String,
        action: @MainActor @Sendable @escaping () -> Void
    ) -> RowViewModel {
        RowViewModel(
            id: ViewID(id),
            title: title,
            systemImage: systemImage,
            action: ViewAction(action: action)
        )
    }
}
