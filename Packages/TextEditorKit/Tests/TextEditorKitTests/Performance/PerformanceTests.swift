import Foundation
import Testing

@testable import TextEditorKit

/// Performance tests for `MarkdownDocumentLayout` and `DocumentEditor`.
///
/// Reference numbers — median of 11 samples (1 warmup discarded), debug
/// build, M-series Mac, swift-tools 6.x, run on 2026-04-26:
///
///     setText 50 blocks   (~1.5 KB)         ~1 ms        budget  10 ms
///     setText 500 blocks  (~16  KB)         ~10 ms       budget  50 ms
///     setText 2000 blocks (~65  KB)         ~37 ms       budget 200 ms
///     update  50 blocks                     ~85 µs       budget   1 ms
///     update  500 blocks                    ~230 µs      budget   2 ms
///     update  2000 blocks                   ~550 µs      budget   5 ms
///     lineToken query (500 blocks)          ~3 µs        budget 100 µs
///     userScenario worst keystroke          ~380 µs      budget   5 ms
///     editorScenario worst operation        ~800 µs      budget   5 ms
///     updateVsFullReparse speedup           ~47×         budget  ≥5×
///     insert small table (3×3)              ~320 µs      budget   5 ms
///     insert large table (10×50, 510 cells) ~11 ms       budget  50 ms
///     setText 50 tables (~3.3 KB)           ~7 ms        budget 100 ms
///     typing in table cell                  ~145 µs      budget   2 ms
///     read TableInfo at cursor              ~33 µs       budget 100 µs
///
/// Budgets are sized at ~5–50× current medians so they absorb runner
/// variance and don't flake, while still catching genuine regressions
/// (something silently making `update` cost as much as a full reparse, or
/// pushing a keystroke past the 8.3 ms / 120 Hz frame budget). Update the
/// reference numbers above when the implementation legitimately changes —
/// the budgets themselves should only widen if the user-perceptible cost is
/// still acceptable.
@Suite("Performance")
struct PerformanceTests {

    // MARK: - Document generation

    private static func generateDocument(blocks: Int) -> String {
        var lines: [String] = []
        for i in 0..<blocks {
            switch i % 5 {
            case 0:
                lines.append("# Heading \(i)")
                lines.append("")
            case 1:
                lines.append("Paragraph \(i) with **bold** and *italic* text and some content.")
                lines.append("")
            case 2:
                lines.append("- List item \(i)")
                lines.append("- Another item")
                lines.append("")
            case 3:
                lines.append("```swift")
                lines.append("let x\(i) = \(i)")
                lines.append("```")
                lines.append("")
            case 4:
                lines.append("> Blockquote \(i)")
                lines.append("")
            default:
                break
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Measurement helper

    /// Runs `setup` (un-timed) + `body` (timed) `samples + warmup` times,
    /// discards the first `warmup` samples, and returns the median. Median
    /// is more stable than mean on noisy CI runners. `setup` is for things
    /// like resetting state between samples that shouldn't be in the number.
    private static func measureMedian(
        samples: Int = 11,
        warmup: Int = 1,
        setup: () -> Void = {},
        _ body: () -> Void
    ) -> Duration {
        for _ in 0..<warmup {
            setup()
            body()
        }
        var durations: [Duration] = []
        durations.reserveCapacity(samples)
        for _ in 0..<samples {
            setup()
            let t = ContinuousClock.now
            body()
            durations.append(ContinuousClock.now - t)
        }
        durations.sort()
        return durations[durations.count / 2]
    }

    private static func ratio(_ a: Duration, _ b: Duration) -> Double {
        func atto(_ d: Duration) -> Double {
            Double(d.components.seconds) * 1e18 + Double(d.components.attoseconds)
        }
        return atto(a) / max(1, atto(b))
    }

    // MARK: - setText (full parse)

    @Test @MainActor
    func setTextSmall() {
        let text = Self.generateDocument(blocks: 50)
        let storage = MarkdownDocumentLayout()

        let median = Self.measureMedian {
            storage.setText(text)
        }

        print("📊 setText (50 blocks, \(text.utf16.count) UTF-16): median \(median)")
        #expect(median < .milliseconds(10))
    }

    @Test @MainActor
    func setTextMedium() {
        let text = Self.generateDocument(blocks: 500)
        let storage = MarkdownDocumentLayout()

        let median = Self.measureMedian {
            storage.setText(text)
        }

        print("📊 setText (500 blocks, \(text.utf16.count) UTF-16): median \(median)")
        #expect(median < .milliseconds(50))
    }

    @Test @MainActor
    func setTextLarge() {
        let text = Self.generateDocument(blocks: 2000)
        let storage = MarkdownDocumentLayout()

        let median = Self.measureMedian(samples: 7) {
            storage.setText(text)
        }

        print("📊 setText (2000 blocks, \(text.utf16.count) UTF-16): median \(median)")
        #expect(median < .milliseconds(200))
    }

    // MARK: - Incremental update

    /// Pre-builds the `(text, newText, range, replacementLength)` tuples for
    /// `iterations` single-character inserts at the midpoint, so the timed
    /// loop only contains `BlockIndex.applyEdit`-related work — no String
    /// manipulation, no offset arithmetic.
    private static func makeUpdates(in text: String, iterations: Int) -> [(newText: String, range: Range<Int>, replacementLength: Int)] {
        let midpoint = text.utf16.count / 2
        var current = text
        var updates: [(newText: String, range: Range<Int>, replacementLength: Int)] = []
        updates.reserveCapacity(iterations)
        for i in 0..<iterations {
            let insertAt = midpoint + i
            let idx = current.index(current.startIndex, offsetBy: insertAt)
            current = String(current[..<idx]) + "x" + String(current[idx...])
            updates.append((current, insertAt..<insertAt, 1))
        }
        return updates
    }

    @Test @MainActor
    func updateSmall() {
        let text = Self.generateDocument(blocks: 50)
        let updates = Self.makeUpdates(in: text, iterations: 100)
        let storage = MarkdownDocumentLayout()

        let median = Self.measureMedian(setup: { storage.setText(text) }) {
            for u in updates {
                storage.update(newText: u.newText, changedRange: u.range, replacementLength: u.replacementLength)
            }
        } / 100

        print("📊 update (50 blocks): median \(median)")
        #expect(median < .milliseconds(1))
    }

    @Test @MainActor
    func updateMedium() {
        let text = Self.generateDocument(blocks: 500)
        let updates = Self.makeUpdates(in: text, iterations: 50)
        let storage = MarkdownDocumentLayout()

        let median = Self.measureMedian(setup: { storage.setText(text) }) {
            for u in updates {
                storage.update(newText: u.newText, changedRange: u.range, replacementLength: u.replacementLength)
            }
        } / 50

        print("📊 update (500 blocks): median \(median)")
        #expect(median < .milliseconds(2))
    }

    @Test @MainActor
    func updateLarge() {
        let text = Self.generateDocument(blocks: 2000)
        let updates = Self.makeUpdates(in: text, iterations: 20)
        let storage = MarkdownDocumentLayout()

        let median = Self.measureMedian(samples: 7, setup: { storage.setText(text) }) {
            for u in updates {
                storage.update(newText: u.newText, changedRange: u.range, replacementLength: u.replacementLength)
            }
        } / 20

        print("📊 update (2000 blocks): median \(median)")
        #expect(median < .milliseconds(5))
    }

    // MARK: - Token query

    @Test @MainActor
    func queryAfterUpdate() {
        let text = Self.generateDocument(blocks: 500)
        let storage = MarkdownDocumentLayout()
        storage.setText(text)
        let lines = storage.lineCount
        let iterations = 1000

        let median = Self.measureMedian {
            for i in 0..<iterations {
                _ = storage.lineToken(at: i % lines)
            }
        } / iterations

        print("📊 lineToken query (500 blocks, \(lines) lines): median \(median)")
        #expect(median < .microseconds(100))
    }

    // MARK: - Speedup

    @Test @MainActor
    func updateVsFullReparse() {
        let text = Self.generateDocument(blocks: 500)
        let storage = MarkdownDocumentLayout()

        let midpoint = text.utf16.count / 2
        let before = String(text.prefix(midpoint))
        let after = String(text.dropFirst(midpoint))
        let newText = before + "x" + after

        // Reset to `text` between samples (un-timed) so the update always
        // starts from the same baseline state.
        let updateMedian = Self.measureMedian(setup: { storage.setText(text) }) {
            storage.update(
                newText: newText,
                changedRange: midpoint..<midpoint,
                replacementLength: 1
            )
        }

        let reparseMedian = Self.measureMedian {
            storage.setText(newText)
        }

        let speedup = Self.ratio(reparseMedian, updateMedian)

        print("📊 500 blocks comparison:")
        print("   Full reparse (median): \(reparseMedian)")
        print("   Incremental  (median): \(updateMedian)")
        print("   Speedup:               \(String(format: "%.1f", speedup))×")
        #expect(speedup >= 5.0)
    }

    // MARK: - User scenarios

    @Test @MainActor
    func userScenario() {
        let text = Self.generateDocument(blocks: 1000)
        let storage = MarkdownDocumentLayout()
        let utf16Count = text.utf16.count

        let loadMedian = Self.measureMedian(samples: 5) {
            storage.setText(text)
        }
        let lines = storage.lineCount
        print("📊 User scenario (1000 blocks, \(lines) lines, \(utf16Count) UTF-16)")
        print("   Load:  median \(loadMedian)")
        #expect(loadMedian < .milliseconds(100))

        // Pre-build typing updates at the midpoint.
        let midUpdates = Self.makeUpdates(in: text, iterations: 50)
        let typingMedian = Self.measureMedian(setup: { storage.setText(text) }) {
            for u in midUpdates {
                storage.update(newText: u.newText, changedRange: u.range, replacementLength: u.replacementLength)
            }
        } / 50
        print("   Typing keystroke: median \(typingMedian)")
        #expect(typingMedian < .milliseconds(5))

        // Toolbar-state query: lineToken + inlineTokens at a fixed line.
        let queryMedian = Self.measureMedian {
            for i in 0..<50 {
                let line = min((lines / 2) + i, storage.lineCount - 1)
                _ = storage.lineToken(at: line)
                _ = storage.inlineTokens(at: SourcePosition(line: line, column: 5))
            }
        } / 50
        print("   Query (lineToken + inlineTokens): median \(queryMedian)")
        #expect(queryMedian < .milliseconds(1))

        // Paste a 50-line block in the middle.
        let pasteContent = (0..<50).map { "Pasted line \($0)" }.joined(separator: "\n")
        let pastePoint = text.utf16.count / 2
        let pasteIdx = text.index(text.startIndex, offsetBy: pastePoint)
        let textAfterPaste = String(text[..<pasteIdx]) + pasteContent + String(text[pasteIdx...])
        let pasteMedian = Self.measureMedian(samples: 5, setup: { storage.setText(text) }) {
            storage.update(
                newText: textAfterPaste,
                changedRange: pastePoint..<pastePoint,
                replacementLength: pasteContent.utf16.count
            )
        }
        print("   Paste 50 lines: median \(pasteMedian)")
        #expect(pasteMedian < .milliseconds(50))
    }

    @Test @MainActor
    func editorScenario() {
        let text = Self.generateDocument(blocks: 1000)

        // Build editor + input freshly per iteration to avoid cross-run state
        // (undo stack growth, etc.) skewing the median.
        let typingMedian = Self.measureMedian(samples: 5) {
            let editor = DocumentEditor()
            let mockInput = MockTextInput()
            editor.attach(to: mockInput)
            editor.loadText(text)

            var currentText = text
            let typingPoint = text.utf16.count / 2
            for i in 0..<50 {
                let insertAt = typingPoint + i
                let idx = currentText.index(currentText.startIndex, offsetBy: insertAt)
                currentText = String(currentText[..<idx]) + "a" + String(currentText[idx...])
                mockInput.simulateChange(
                    range: NSRange(location: insertAt, length: 0),
                    replacement: "a",
                    newText: currentText
                )
            }
        } / 50

        print("📊 Editor scenario (1000 blocks): typing keystroke median \(typingMedian)")
        #expect(typingMedian < .milliseconds(5))

        // Toolbar isActive batch: 4 queries, repeat to amortise.
        let editor = DocumentEditor()
        let mockInput = MockTextInput()
        editor.attach(to: mockInput)
        editor.loadText(text)
        let toolbarMedian = Self.measureMedian {
            for _ in 0..<50 {
                _ = editor.isActive(.format(.bold))
                _ = editor.isActive(.format(.italic))
                _ = editor.isActive(.format(.heading(2)))
                _ = editor.isActive(.format(.list))
            }
        } / 200  // 50 batches × 4 queries
        print("   Toolbar isActive: median per query \(toolbarMedian)")
        #expect(toolbarMedian < .milliseconds(1))
    }

    // MARK: - Tables

    @Test @MainActor
    func insertSmallTable() {
        let table = MarkdownTable(
            headers: ["A", "B", "C"],
            rows: [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]
        )
        let handler = TableActionHandler(table: table)
        let ctx = makeContext("", cursor: 0)

        let median = Self.measureMedian {
            _ = handler.activate(in: ctx)
        }

        print("📊 insert small table (3×3): median \(median)")
        #expect(median < .milliseconds(5))
    }

    @Test @MainActor
    func insertLargeTable() {
        let headers = (0..<10).map { "Col \($0)" }
        let rows = (0..<50).map { row in
            (0..<10).map { col in "Cell \(row)-\(col)" }
        }
        let table = MarkdownTable(headers: headers, rows: rows)
        let handler = TableActionHandler(table: table)
        let ctx = makeContext("", cursor: 0)

        let median = Self.measureMedian(samples: 7) {
            _ = handler.activate(in: ctx)
        }

        print("📊 insert large table (10×50, 510 cells): median \(median)")
        #expect(median < .milliseconds(50))
    }

    @Test @MainActor
    func setTextManyTables() {
        // 50 small tables interleaved with paragraphs.
        var lines: [String] = []
        for i in 0..<50 {
            lines.append("Paragraph before table \(i).")
            lines.append("")
            lines.append("|H1|H2|H3|")
            lines.append("|--|--|--|")
            lines.append("|a|b|c|")
            lines.append("|d|e|f|")
            lines.append("")
        }
        let text = lines.joined(separator: "\n")
        let storage = MarkdownDocumentLayout()

        let median = Self.measureMedian {
            storage.setText(text)
        }

        print("📊 setText (50 tables, \(text.utf16.count) UTF-16): median \(median)")
        #expect(median < .milliseconds(100))
    }

    @Test @MainActor
    func typingInsideTableCell() {
        // Document: paragraph + table + paragraph. Cursor inside a body cell.
        let prefix = "Some paragraph above the table.\n\n"
        let tableLines = [
            "|H1|H2|H3|",
            "|--|--|--|",
            "|a|b|c|",
            "|d|e|f|",
        ]
        let suffix = "\n\nSome paragraph below the table."
        let baseText = prefix + tableLines.joined(separator: "\n") + suffix
        // Insert cursor lands in the middle of `b` on row 0 of the body
        // (the line "|a|b|c|"). Compute its UTF-16 offset.
        let bOffset =
            (prefix
                + tableLines[0] + "\n"
                + tableLines[1] + "\n"
                + "|a|").utf16.count + 1  // after the `b`

        // Pre-build 30 single-character inserts at successive positions.
        var current = baseText
        var updates: [(newText: String, range: Range<Int>, replacementLength: Int)] = []
        for i in 0..<30 {
            let insertAt = bOffset + i
            let idx = current.index(current.startIndex, offsetBy: insertAt)
            current = String(current[..<idx]) + "x" + String(current[idx...])
            updates.append((current, insertAt..<insertAt, 1))
        }

        let storage = MarkdownDocumentLayout()
        let median = Self.measureMedian(setup: { storage.setText(baseText) }) {
            for u in updates {
                storage.update(
                    newText: u.newText, changedRange: u.range, replacementLength: u.replacementLength)
            }
        } / 30

        print("📊 typing in table cell: median per keystroke \(median)")
        #expect(median < .milliseconds(2))
    }

    @Test @MainActor
    func readTableInfoAtCursor() {
        // Document with a table; cursor on a body row. Read the cached
        // `MarkdownLineToken.TableInfo` — this is what `EditTableActionHandler`
        // does when the user taps the toolbar button.
        let text = """
            Paragraph before.

            |Name|Score|
            |----|-----|
            |Alice|10|
            |Bob|20|
            |Carol|30|

            Paragraph after.
            """
        let storage = MarkdownDocumentLayout()
        storage.setText(text)
        // Body row "|Alice|10|" is at line index 4 (0-based).
        let line = 4

        let median = Self.measureMedian {
            for _ in 0..<100 {
                _ = storage.lineToken(at: line)
            }
        } / 100

        print("📊 read TableInfo at cursor (3-row table): median \(median)")
        #expect(median < .microseconds(100))
    }
}
