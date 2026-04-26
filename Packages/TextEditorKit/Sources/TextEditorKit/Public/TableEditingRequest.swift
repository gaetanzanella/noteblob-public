import Foundation

public struct TableEditingRequest: Hashable, Sendable {

    public let currentTable: MarkdownTable

    public init(currentTable: MarkdownTable) {
        self.currentTable = currentTable
    }
}
