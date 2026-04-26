import Foundation

// MARK: - UndoMergeStrategy

/// Decides whether an incoming text edit should be merged into the previous
/// undo entry (coalesced) or should open a new undo step.
@MainActor
protocol UndoMergeStrategy: AnyObject {
    /// Called on every text change. Return `true` to coalesce into the
    /// previous undo entry (don't push a new one), `false` to start a new
    /// undo step.
    func shouldMerge() -> Bool

    /// Reset any internal state — called on load or when the history is
    /// cleared/unwound (undo/redo).
    func reset()
}

// MARK: - TimeBasedMergeStrategy

/// Production default: merge edits that arrive within a fixed window of
/// each other, which gives single-undo for continuous typing pauses.
@MainActor
final class TimeBasedMergeStrategy: UndoMergeStrategy {

    private let window: TimeInterval
    private var lastActivity: Date?

    init(window: TimeInterval = 0.5) {
        self.window = window
    }

    func shouldMerge() -> Bool {
        let now = Date()
        defer { lastActivity = now }
        guard let last = lastActivity else { return false }
        return now.timeIntervalSince(last) < window
    }

    func reset() {
        lastActivity = nil
    }
}
