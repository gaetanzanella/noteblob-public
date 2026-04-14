import Foundation

// MARK: - EditorContext

@MainActor
struct EditorContext {
    private let selection: Range<SourcePosition>
    private let selectionUTF16: Range<Int>
    private let text: String
    private let documentLayout: any DocumentLayout
    let documentURL: URL?

    init(selectionUTF16: Range<Int>, text: String, documentLayout: any DocumentLayout, documentURL: URL? = nil) {
        self.selectionUTF16 = selectionUTF16
        let start = documentLayout.sourcePosition(at: selectionUTF16.lowerBound)
        let end = documentLayout.sourcePosition(at: selectionUTF16.upperBound)
        self.selection = start..<end
        self.text = text
        self.documentLayout = documentLayout
        self.documentURL = documentURL
    }

    func markdown() -> MarkdownContext? {
        (documentLayout as? MarkdownDocumentLayout).map {
            MarkdownContext(storage: $0, selection: selection)
        }
    }

    var currentText: String {
        text
    }

    var currentLine: Int {
        selection.lowerBound.line
    }

    var lineCount: Int {
        documentLayout.lineCount
    }

    func currentLineRange() -> Range<Int> {
        documentLayout.lineRange(at: selection.lowerBound.line)
    }

    func lineRange(at line: Int) -> Range<Int> {
        documentLayout.lineRange(at: line)
    }

    func selectionOffsets() -> Range<Int> {
        selectionUTF16
    }

    func offset(of position: SourcePosition) -> Int {
        documentLayout.offset(of: position)
    }
}
