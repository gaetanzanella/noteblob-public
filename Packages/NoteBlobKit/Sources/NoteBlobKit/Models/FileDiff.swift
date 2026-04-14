import Foundation

public struct FileDiff: Sendable {

    public struct Hunk: Sendable {

        public struct Line: Sendable {
            public enum Kind: Sendable {
                case context
                case addition
                case deletion
            }

            public let kind: Kind
            public let content: String

            public init(kind: Kind, content: String) {
                self.kind = kind
                self.content = content
            }
        }

        public let header: String
        public let lines: [Line]

        public init(header: String, lines: [Line]) {
            self.header = header
            self.lines = lines
        }
    }

    public let path: String
    public let hunks: [Hunk]

    public init(path: String, hunks: [Hunk]) {
        self.path = path
        self.hunks = hunks
    }
}
