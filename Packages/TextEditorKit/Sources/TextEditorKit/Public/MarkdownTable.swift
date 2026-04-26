import Foundation

public struct MarkdownTable: Hashable, Sendable {

    public let headers: [String]
    public let rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}
