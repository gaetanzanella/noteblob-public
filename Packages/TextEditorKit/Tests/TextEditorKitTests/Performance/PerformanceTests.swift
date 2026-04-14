import Foundation
import Testing

@testable import TextEditorKit

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

    // MARK: - setText (full parse)

    @Test @MainActor
    func setTextSmall() {
        let text = Self.generateDocument(blocks: 50)
        let storage = MarkdownDocumentLayout()

        let start = ContinuousClock.now
        for _ in 0..<100 {
            storage.setText(text)
        }
        let elapsed = ContinuousClock.now - start
        let avg = elapsed / 100

        print("📊 setText (50 blocks, \(text.utf16.count) UTF-16): avg \(avg)")
    }

    @Test @MainActor
    func setTextMedium() {
        let text = Self.generateDocument(blocks: 500)
        let storage = MarkdownDocumentLayout()

        let start = ContinuousClock.now
        for _ in 0..<10 {
            storage.setText(text)
        }
        let elapsed = ContinuousClock.now - start
        let avg = elapsed / 10

        print("📊 setText (500 blocks, \(text.utf16.count) UTF-16): avg \(avg)")
    }

    @Test @MainActor
    func setTextLarge() {
        let text = Self.generateDocument(blocks: 2000)
        let storage = MarkdownDocumentLayout()

        let start = ContinuousClock.now
        for _ in 0..<5 {
            storage.setText(text)
        }
        let elapsed = ContinuousClock.now - start
        let avg = elapsed / 5

        print("📊 setText (2000 blocks, \(text.utf16.count) UTF-16): avg \(avg)")
    }

    // MARK: - Incremental update (single character insert in middle)

    @Test @MainActor
    func updateSmall() {
        let text = Self.generateDocument(blocks: 50)
        let storage = MarkdownDocumentLayout()
        storage.setText(text)

        let midpoint = text.utf16.count / 2
        let iterations = 100
        var currentText = text

        let start = ContinuousClock.now
        for i in 0..<iterations {
            let char = "x"
            let insertAt = midpoint + i
            let before = String(currentText.prefix(insertAt))
            let after = String(currentText.dropFirst(insertAt))
            currentText = before + char + after
            storage.update(
                newText: currentText,
                changedRange: insertAt..<insertAt,
                replacementLength: 1
            )
        }
        let elapsed = ContinuousClock.now - start
        let avg = elapsed / iterations

        print("📊 update (50 blocks): avg \(avg)")
    }

    @Test @MainActor
    func updateMedium() {
        let text = Self.generateDocument(blocks: 500)
        let storage = MarkdownDocumentLayout()
        storage.setText(text)

        let midpoint = text.utf16.count / 2
        let iterations = 50
        var currentText = text

        let start = ContinuousClock.now
        for i in 0..<iterations {
            let char = "x"
            let insertAt = midpoint + i
            let before = String(currentText.prefix(insertAt))
            let after = String(currentText.dropFirst(insertAt))
            currentText = before + char + after
            storage.update(
                newText: currentText,
                changedRange: insertAt..<insertAt,
                replacementLength: 1
            )
        }
        let elapsed = ContinuousClock.now - start
        let avg = elapsed / iterations

        print("📊 update (500 blocks): avg \(avg)")
    }

    @Test @MainActor
    func updateLarge() {
        let text = Self.generateDocument(blocks: 2000)
        let storage = MarkdownDocumentLayout()
        storage.setText(text)

        let midpoint = text.utf16.count / 2
        let iterations = 20
        var currentText = text

        let start = ContinuousClock.now
        for i in 0..<iterations {
            let char = "x"
            let insertAt = midpoint + i
            let before = String(currentText.prefix(insertAt))
            let after = String(currentText.dropFirst(insertAt))
            currentText = before + char + after
            storage.update(
                newText: currentText,
                changedRange: insertAt..<insertAt,
                replacementLength: 1
            )
        }
        let elapsed = ContinuousClock.now - start
        let avg = elapsed / iterations

        print("📊 update (2000 blocks): avg \(avg)")
    }

    // MARK: - Token query after update

    @Test @MainActor
    func queryAfterUpdate() {
        let text = Self.generateDocument(blocks: 500)
        let storage = MarkdownDocumentLayout()
        storage.setText(text)

        let lines = storage.lineCount
        let iterations = 1000

        let start = ContinuousClock.now
        for i in 0..<iterations {
            let line = i % lines
            _ = storage.lineToken(at: line)
        }
        let elapsed = ContinuousClock.now - start
        let avg = elapsed / iterations

        print("📊 lineToken query (500 blocks, \(lines) lines): avg \(avg)")
    }

    // MARK: - User scenario

    @Test @MainActor
    func userScenario() {
        let text = Self.generateDocument(blocks: 1000)
        let storage = MarkdownDocumentLayout()

        // 1. Open document
        let loadStart = ContinuousClock.now
        storage.setText(text)
        let loadTime = ContinuousClock.now - loadStart
        let lines = storage.lineCount
        let utf16Count = text.utf16.count
        print("📊 User scenario (1000 blocks, \(lines) lines, \(utf16Count) UTF-16)")
        print("   Load:             \(loadTime)")

        // 2. Typing at middle of document — 50 keystrokes
        var currentText = text
        let typingPoint = utf16Count / 2
        var typingTotal: Duration = .zero
        for i in 0..<50 {
            let insertAt = typingPoint + i
            let idx = currentText.index(currentText.startIndex, offsetBy: insertAt)
            currentText = String(currentText[..<idx]) + "a" + String(currentText[idx...])
            let t = ContinuousClock.now
            storage.update(
                newText: currentText,
                changedRange: insertAt..<insertAt,
                replacementLength: 1
            )
            typingTotal += ContinuousClock.now - t
        }
        print("   Typing (50 keys): avg \(typingTotal / 50)")

        // 3. Query toolbar state after each keystroke (lineToken + inlineTokens)
        var queryTotal: Duration = .zero
        for i in 0..<50 {
            let line = (lines / 2) + i
            let pos = SourcePosition(line: min(line, storage.lineCount - 1), column: 5)
            let t = ContinuousClock.now
            _ = storage.lineToken(at: pos.line)
            _ = storage.inlineTokens(at: pos)
            queryTotal += ContinuousClock.now - t
        }
        print("   Query (50x):      avg \(queryTotal / 50)")

        // 4. Paste a large block (50 lines) in the middle
        let pasteContent = (0..<50).map { "Pasted line \($0)" }.joined(separator: "\n")
        let pastePoint = currentText.utf16.count / 2
        let pasteIdx = currentText.index(currentText.startIndex, offsetBy: pastePoint)
        let textAfterPaste =
            String(currentText[..<pasteIdx]) + pasteContent + String(currentText[pasteIdx...])

        let pasteStart = ContinuousClock.now
        storage.update(
            newText: textAfterPaste,
            changedRange: pastePoint..<pastePoint,
            replacementLength: pasteContent.utf16.count
        )
        let pasteTime = ContinuousClock.now - pasteStart
        currentText = textAfterPaste
        print("   Paste (50 lines): \(pasteTime)")

        // 5. Delete a large selection (100 characters)
        let deleteStart16 = currentText.utf16.count / 3
        let deleteEnd16 = deleteStart16 + 100
        let delStartIdx = currentText.index(currentText.startIndex, offsetBy: deleteStart16)
        let delEndIdx = currentText.index(currentText.startIndex, offsetBy: deleteEnd16)
        let textAfterDelete =
            String(currentText[..<delStartIdx]) + String(currentText[delEndIdx...])

        let deleteStart = ContinuousClock.now
        storage.update(
            newText: textAfterDelete,
            changedRange: deleteStart16..<deleteEnd16,
            replacementLength: 0
        )
        let deleteTime = ContinuousClock.now - deleteStart
        currentText = textAfterDelete
        print("   Delete (100ch):   \(deleteTime)")

        // 6. Typing at the very end of document
        var endTypingTotal: Duration = .zero
        for i in 0..<20 {
            let insertAt = currentText.utf16.count
            currentText = currentText + "z"
            let t = ContinuousClock.now
            storage.update(
                newText: currentText,
                changedRange: insertAt..<insertAt,
                replacementLength: 1
            )
            endTypingTotal += ContinuousClock.now - t
        }
        print("   End typing (20):  avg \(endTypingTotal / 20)")

        // 7. Typing at the very start of document
        var startTypingTotal: Duration = .zero
        for _ in 0..<20 {
            currentText = "z" + currentText
            let t = ContinuousClock.now
            storage.update(
                newText: currentText,
                changedRange: 0..<0,
                replacementLength: 1
            )
            startTypingTotal += ContinuousClock.now - t
        }
        print("   Start typing (20): avg \(startTypingTotal / 20)")

        // Budget check
        let maxKeystroke = max(
            typingTotal / 50,
            endTypingTotal / 20,
            startTypingTotal / 20
        )
        print("   Worst keystroke:  \(maxKeystroke) (budget: 8.3ms for 120Hz)")
    }

    // MARK: - Full editor scenario

    @Test @MainActor
    func editorScenario() {
        let text = Self.generateDocument(blocks: 1000)
        let editor = DocumentEditor()
        let mockInput = MockTextInput()
        editor.attach(to: mockInput)

        // 1. Load document
        let loadStart = ContinuousClock.now
        editor.loadText(text)
        let loadTime = ContinuousClock.now - loadStart
        print("📊 Editor scenario (1000 blocks, \(text.utf16.count) UTF-16)")
        print("   Load:             \(loadTime)")

        // 2. Typing in the middle — simulate UIKit delegate calls
        var currentText = text
        let typingPoint = text.utf16.count / 2
        var typingTotal: Duration = .zero
        for i in 0..<50 {
            let insertAt = typingPoint + i
            let oldText = currentText
            let idx = currentText.index(currentText.startIndex, offsetBy: insertAt)
            currentText = String(currentText[..<idx]) + "a" + String(currentText[idx...])

            let t = ContinuousClock.now
            mockInput.simulateChange(
                range: NSRange(location: insertAt, length: 0),
                replacement: "a",
                newText: currentText
            )
            typingTotal += ContinuousClock.now - t
        }
        print("   Typing (50 keys): avg \(typingTotal / 50)")

        // 3. Check toolbar state
        var actionTotal: Duration = .zero
        for _ in 0..<50 {
            let t = ContinuousClock.now
            _ = editor.isActive(.format(.bold))
            _ = editor.isActive(.format(.italic))
            _ = editor.isActive(.format(.heading(2)))
            _ = editor.isActive(.format(.list))
            actionTotal += ContinuousClock.now - t
        }
        print("   Toolbar (50x4):   avg \(actionTotal / 50)")

        // 4. Paste
        let pasteContent = (0..<50).map { "Pasted line \($0)" }.joined(separator: "\n")
        let pastePoint = currentText.utf16.count / 2
        let oldText = currentText
        let pasteIdx = currentText.index(currentText.startIndex, offsetBy: pastePoint)
        currentText =
            String(currentText[..<pasteIdx]) + pasteContent + String(currentText[pasteIdx...])

        let pasteStart = ContinuousClock.now
        mockInput.simulateChange(
            range: NSRange(location: pastePoint, length: 0),
            replacement: pasteContent,
            newText: currentText
        )
        let pasteTime = ContinuousClock.now - pasteStart
        print("   Paste (50 lines): \(pasteTime)")

        // 5. Apply bold action
        mockInput._selectedRange = NSRange(location: pastePoint, length: 10)
        let boldStart = ContinuousClock.now
        editor.apply(.format(.bold))
        let boldTime = ContinuousClock.now - boldStart
        currentText = mockInput._text
        print("   Apply bold:       \(boldTime)")

        // 6. Delete selection
        let deletePoint = currentText.utf16.count / 3
        let deleteLen = 200
        let delOldText = currentText
        let delStartIdx = currentText.index(currentText.startIndex, offsetBy: deletePoint)
        let delEndIdx = currentText.index(currentText.startIndex, offsetBy: deletePoint + deleteLen)
        currentText = String(currentText[..<delStartIdx]) + String(currentText[delEndIdx...])

        let deleteStart = ContinuousClock.now
        mockInput.simulateChange(
            range: NSRange(location: deletePoint, length: deleteLen),
            replacement: "",
            newText: currentText
        )
        let deleteTime = ContinuousClock.now - deleteStart
        print("   Delete (200ch):   \(deleteTime)")

        let worst = max(typingTotal / 50, pasteTime, deleteTime)
        print("   Worst operation:  \(worst) (budget: 8.3ms)")
    }

    // MARK: - Comparison: update vs full reparse

    @Test @MainActor
    func updateVsFullReparse() {
        let text = Self.generateDocument(blocks: 500)
        let storage = MarkdownDocumentLayout()
        storage.setText(text)

        let midpoint = text.utf16.count / 2
        let before = String(text.prefix(midpoint))
        let after = String(text.dropFirst(midpoint))
        let newText = before + "x" + after

        // Measure incremental update (reset outside the measurement)
        var updateTotal: Duration = .zero
        for _ in 0..<50 {
            storage.setText(text)  // reset outside measurement
            let t = ContinuousClock.now
            storage.update(
                newText: newText,
                changedRange: midpoint..<midpoint,
                replacementLength: 1
            )
            updateTotal += ContinuousClock.now - t
        }
        let updateTime = updateTotal / 50

        // Measure full reparse
        let reparseStart = ContinuousClock.now
        for _ in 0..<50 {
            storage.setText(newText)
        }
        let reparseTime = (ContinuousClock.now - reparseStart) / 50

        let speedup =
            Double(reparseTime.components.attoseconds)
            / Double(max(1, updateTime.components.attoseconds))

        print("📊 500 blocks comparison:")
        print("   Full reparse: \(reparseTime)")
        print("   Incremental:  \(updateTime)")
        print("   Speedup:      \(String(format: "%.1f", speedup))x")
    }
}
