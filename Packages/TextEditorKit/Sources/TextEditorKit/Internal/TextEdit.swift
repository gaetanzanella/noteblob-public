import Foundation

// MARK: - TextEdit

struct TextEdit: Sendable, Equatable {
    let changes: [Change]
    let selection: Range<Int>

    init(changes: [Change], selection: Range<Int>) {
        self.changes = changes
        self.selection = selection
    }

    init(insert string: String, at position: Int) {
        self.changes = [.insert(at: position, string: string)]
        self.selection = (position + string.count)..<(position + string.count)
    }

    enum Change: Sendable, Equatable {
        case insert(at: Int, string: String)
        case replace(range: Range<Int>, with: String)
        case delete(Range<Int>)

        var offset: Int {
            switch self {
            case .insert(let at, _): return at
            case .replace(let range, _): return range.lowerBound
            case .delete(let range): return range.lowerBound
            }
        }
    }
}

// MARK: - Sorting

extension Array where Element == TextEdit.Change {

    /// Sort changes in descending order by offset.
    /// This allows applying changes from end to start without invalidating ranges.
    func sortedDescending() -> [TextEdit.Change] {
        sorted { $0.offset > $1.offset }
    }
}

// MARK: - Range Shifting

extension Range where Bound == Int {

    /// Returns a new range shifted by `delta`.
    func shifted(by delta: Int) -> Range<Int> {
        (lowerBound + delta)..<(upperBound + delta)
    }

    /// Shift the range by `delta`, clamping each bound to at least `floor`.
    /// Use when the shift can go negative (e.g. deleting a prefix) and the
    /// resulting selection must not cross the start of the edited region.
    func shifted(by delta: Int, floor: Int) -> Range<Int> {
        Swift.max(floor, lowerBound + delta)..<Swift.max(floor, upperBound + delta)
    }
}
