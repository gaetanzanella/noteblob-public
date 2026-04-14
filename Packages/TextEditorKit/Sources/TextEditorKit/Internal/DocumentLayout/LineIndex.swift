import Foundation

// MARK: - LineIndex

/// Tracks line boundaries using UTF-16 offsets for direct NSRange compatibility.
/// Rebuilt incrementally when text changes.
struct LineIndex: Sendable, Equatable {

    /// UTF-16 offset of each line start (index 0 = line 0)
    private var lineStarts: [Int]

    /// Total UTF-16 length
    private var length: Int

    // MARK: - Init

    init() {
        self.lineStarts = [0]
        self.length = 0
    }

    init(text: String) {
        self.lineStarts = [0]
        self.length = text.utf16.count

        var offset = 0
        for unit in text.utf16 {
            offset += 1
            if unit == 0x0A { // '\n'
                lineStarts.append(offset)
            }
        }
    }

    // MARK: - Queries

    /// Number of lines in the document
    var lineCount: Int {
        lineStarts.count
    }

    /// Returns the line number (0-based) for a given UTF-16 offset
    func lineNumber(at offset: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1

        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= offset {
                low = mid
            } else {
                high = mid - 1
            }
        }

        return low
    }

    /// Returns the UTF-16 offset range for a line (0-based)
    func lineRange(at lineNumber: Int) -> Range<Int> {
        guard lineNumber >= 0 && lineNumber < lineStarts.count else {
            return length..<length
        }

        let start = lineStarts[lineNumber]
        let end: Int

        if lineNumber + 1 < lineStarts.count {
            end = lineStarts[lineNumber + 1] - 1
        } else {
            end = length
        }

        return start..<max(start, end)
    }

    /// Returns the start UTF-16 offset of a line (0-based)
    func lineStart(at lineNumber: Int) -> Int {
        guard lineNumber >= 0 && lineNumber < lineStarts.count else {
            return length
        }
        return lineStarts[lineNumber]
    }

    /// Returns the end UTF-16 offset of a line (0-based), excluding the newline
    func lineEnd(at lineNumber: Int) -> Int {
        lineRange(at: lineNumber).upperBound
    }

    // MARK: - SourcePosition Conversion

    /// Converts a UTF-16 offset to a SourcePosition (line, column in UTF-16).
    func sourcePosition(at offset: Int) -> SourcePosition {
        let line = lineNumber(at: offset)
        let column = offset - lineStarts[line]
        return SourcePosition(line: line, column: column)
    }

    /// Converts a SourcePosition back to a UTF-16 offset.
    func offset(of position: SourcePosition) -> Int {
        guard position.line >= 0 && position.line < lineStarts.count else {
            return length
        }
        return lineStarts[position.line] + position.column
    }

    // MARK: - Incremental Update

    /// Updates the index after a text change. All offsets are UTF-16.
    mutating func applyEdit(
        replacingRange range: Range<Int>,
        withLength newLength: Int,
        in newText: String
    ) {
        let delta = newLength - range.count

        // Find affected lines
        let startLine = lineNumber(at: range.lowerBound)
        // Use upperBound (not upperBound-1) to include the line AFTER a deleted newline
        let endLine = range.count > 0 ? lineNumber(at: range.upperBound) : startLine

        // Count newlines in the replacement (UTF-16)
        let utf16 = newText.utf16
        let repStart = utf16.index(utf16.startIndex, offsetBy: min(range.lowerBound, utf16.count))
        let repEnd = utf16.index(utf16.startIndex, offsetBy: min(range.lowerBound + newLength, utf16.count))

        var newLineOffsets: [Int] = []
        var offset = range.lowerBound
        for unit in utf16[repStart..<repEnd] {
            offset += 1
            if unit == 0x0A {
                newLineOffsets.append(offset)
            }
        }

        // Remove old line entries for affected range (keep startLine)
        if endLine >= startLine {
            let removeCount = endLine - startLine
            if removeCount > 0 && startLine + 1 < lineStarts.count {
                lineStarts.removeSubrange((startLine + 1)..<min(startLine + 1 + removeCount, lineStarts.count))
            }
        }

        // Insert new line entries
        lineStarts.insert(contentsOf: newLineOffsets, at: startLine + 1)

        // Adjust all subsequent line starts by delta
        let adjustFrom = startLine + 1 + newLineOffsets.count
        if adjustFrom < lineStarts.count {
            for i in adjustFrom..<lineStarts.count {
                lineStarts[i] += delta
            }
        }

        // Update length
        length += delta
    }
}
