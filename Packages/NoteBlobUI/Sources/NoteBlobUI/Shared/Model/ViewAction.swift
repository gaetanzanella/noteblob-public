import Foundation

public struct ViewAction<Parameter>: Sendable {

    let action: @MainActor @Sendable (Parameter) -> Void

    init(action: @MainActor @Sendable @escaping (Parameter) -> Void) {
        self.action = action
    }

    @MainActor
    public func trigger(_ parameter: Parameter) {
        action(parameter)
    }
}

extension ViewAction where Parameter == Void {

    @MainActor
    func trigger() {
        trigger(())
    }

    static func none() -> ViewAction {
        ViewAction(action: { _ in })
    }
}
