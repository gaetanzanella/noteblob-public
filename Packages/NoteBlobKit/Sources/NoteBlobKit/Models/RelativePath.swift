import Foundation

public struct RelativePath: Sendable, Hashable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public init(stringLiteral value: String) {
        self.value = value
    }

    public static let root = RelativePath("")

    public func appending(_ component: String) -> RelativePath {
        if value.isEmpty {
            return RelativePath(component)
        }
        return RelativePath(value + "/" + component)
    }

    public func ancestors() -> [RelativePath] {
        let components = value.split(separator: "/")
        guard components.count > 1 else { return [] }
        return (1..<components.count).map { index in
            RelativePath(components[0..<index].joined(separator: "/"))
        }
    }

    public var parent: RelativePath {
        let components = value.split(separator: "/")
        guard components.count > 1 else { return .root }
        return RelativePath(components.dropLast().joined(separator: "/"))
    }

    public var lastComponent: String {
        value.split(separator: "/").last.map(String.init) ?? value
    }

    public var description: String { value }
}
