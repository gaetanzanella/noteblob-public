import Foundation

// MARK: - SourcePosition

/// A position in a text document, expressed as line and column (both 0-based).
public struct SourcePosition: Equatable, Comparable, Sendable, Hashable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.line, lhs.column) < (rhs.line, rhs.column)
    }
}
