import Foundation

public struct TableDraft: Hashable, Sendable {

    public var headers: [String]
    public var rows: [[String]]

    public var rowCount: Int { rows.count }
    public var columnCount: Int { headers.count }

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }

    static func empty(columns: Int, rows: Int) -> TableDraft {
        TableDraft(
            headers: Array(repeating: "", count: columns),
            rows: Array(repeating: Array(repeating: "", count: columns), count: rows)
        )
    }

    mutating func insertRow(after row: Int) {
        let position = min(max(row + 1, 0), rows.count)
        rows.insert(Array(repeating: "", count: columnCount), at: position)
    }

    mutating func removeRow(at row: Int) {
        guard rows.indices.contains(row) else { return }
        rows.remove(at: row)
    }

    mutating func insertColumn(after column: Int) {
        let position = min(max(column + 1, 0), headers.count)
        headers.insert("", at: position)
        rows = rows.map { row in
            var copy = row
            copy.insert("", at: min(position, copy.count))
            return copy
        }
    }

    mutating func removeColumn(at column: Int) {
        guard headers.indices.contains(column), headers.count > 1 else { return }
        headers.remove(at: column)
        rows = rows.map { row in
            guard row.indices.contains(column) else { return row }
            var copy = row
            copy.remove(at: column)
            return copy
        }
    }

    mutating func setHeader(column: Int, value: String) {
        guard headers.indices.contains(column) else { return }
        headers[column] = value
    }

    mutating func setCell(row: Int, column: Int, value: String) {
        guard rows.indices.contains(row), rows[row].indices.contains(column) else { return }
        rows[row][column] = value
    }
}
