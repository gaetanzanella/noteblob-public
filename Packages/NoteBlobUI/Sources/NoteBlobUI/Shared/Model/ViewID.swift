import Foundation

struct ViewID: Hashable, @unchecked Sendable, Identifiable {

    private let components: [AnyHashable]

    init() {
        self.components = [AnyHashable(UUID())]
    }

    init<T: Hashable & Sendable>(_ value: T) {
        self.components = [AnyHashable(value)]
    }

    func row<R: Hashable>(as type: R.Type) -> R? {
        components.last?.base as? R
    }

    var id: ViewID { self }
}
