import Testing
import Markdown

@Suite("Markdown Parsing Performance")
struct MarkdownParsingPerformanceTests {

    // Base markdown content with various elements
    private static let baseMarkdown = """
    # Heading 1

    This is a paragraph with **bold text** and *italic text* and ~~strikethrough~~.

    ## Heading 2

    Here's a list:
    - Item one with `inline code`
    - Item two with [a link](https://example.com)
    - Item three

    ### Heading 3

    A numbered list:
    1. First item
    2. Second item
    3. Third item

    ```swift
    func example() {
        let x = 42
        print("Hello, world!")
    }
    ```

    > This is a blockquote
    > with multiple lines

    ---

    Another paragraph with more **bold** and *italic* text.

    - [ ] Todo item unchecked
    - [x] Todo item checked

    | Column 1 | Column 2 | Column 3 |
    |----------|----------|----------|
    | Cell 1   | Cell 2   | Cell 3   |
    | Cell 4   | Cell 5   | Cell 6   |

    """

    private static func generateMarkdown(copies: Int) -> String {
        String(repeating: baseMarkdown, count: copies)
    }

    private static func measureParsing(_ markdown: String) -> (duration: Duration, document: Document) {
        let clock = ContinuousClock()
        var document: Document!
        let duration = clock.measure {
            document = Document(parsing: markdown)
        }
        return (duration, document)
    }

    @Test("Parse small document (~1KB)")
    func parseSmallDocument() {
        let markdown = Self.generateMarkdown(copies: 1)
        let sizeKB = Double(markdown.utf8.count) / 1024.0
        let lineCount = markdown.components(separatedBy: "\n").count

        let (duration, document) = Self.measureParsing(markdown)

        print("📄 Small document:")
        print("   Size: \(String(format: "%.2f", sizeKB)) KB")
        print("   Lines: \(lineCount)")
        print("   Time: \(duration)")
        print("   Blocks: \(document.childCount)")

        #expect(document.childCount > 0)
    }

    @Test("Parse medium document (~10KB)")
    func parseMediumDocument() {
        let markdown = Self.generateMarkdown(copies: 10)
        let sizeKB = Double(markdown.utf8.count) / 1024.0
        let lineCount = markdown.components(separatedBy: "\n").count

        let (duration, document) = Self.measureParsing(markdown)

        print("📄 Medium document:")
        print("   Size: \(String(format: "%.2f", sizeKB)) KB")
        print("   Lines: \(lineCount)")
        print("   Time: \(duration)")
        print("   Blocks: \(document.childCount)")

        #expect(document.childCount > 0)
    }

    @Test("Parse large document (~100KB)")
    func parseLargeDocument() {
        let markdown = Self.generateMarkdown(copies: 100)
        let sizeKB = Double(markdown.utf8.count) / 1024.0
        let lineCount = markdown.components(separatedBy: "\n").count

        let (duration, document) = Self.measureParsing(markdown)

        print("📄 Large document:")
        print("   Size: \(String(format: "%.2f", sizeKB)) KB")
        print("   Lines: \(lineCount)")
        print("   Time: \(duration)")
        print("   Blocks: \(document.childCount)")

        #expect(document.childCount > 0)
    }

    @Test("Parse very large document (~500KB)")
    func parseVeryLargeDocument() {
        let markdown = Self.generateMarkdown(copies: 500)
        let sizeKB = Double(markdown.utf8.count) / 1024.0
        let lineCount = markdown.components(separatedBy: "\n").count

        let (duration, document) = Self.measureParsing(markdown)

        print("📄 Very large document:")
        print("   Size: \(String(format: "%.2f", sizeKB)) KB")
        print("   Lines: \(lineCount)")
        print("   Time: \(duration)")
        print("   Blocks: \(document.childCount)")

        #expect(document.childCount > 0)
    }

    @Test("Parse huge document (~1MB)")
    func parseHugeDocument() {
        let markdown = Self.generateMarkdown(copies: 1000)
        let sizeKB = Double(markdown.utf8.count) / 1024.0
        let lineCount = markdown.components(separatedBy: "\n").count

        let (duration, document) = Self.measureParsing(markdown)

        print("📄 Huge document:")
        print("   Size: \(String(format: "%.2f", sizeKB)) KB (\(String(format: "%.2f", sizeKB / 1024)) MB)")
        print("   Lines: \(lineCount)")
        print("   Time: \(duration)")
        print("   Blocks: \(document.childCount)")

        #expect(document.childCount > 0)
    }

    @Test("Repeated parsing (10 iterations)")
    func repeatedParsing() {
        let markdown = Self.generateMarkdown(copies: 50) // ~50KB
        let sizeKB = Double(markdown.utf8.count) / 1024.0
        let lineCount = markdown.components(separatedBy: "\n").count
        let iterations = 10

        let clock = ContinuousClock()
        var durations: [Duration] = []

        for _ in 0..<iterations {
            let duration = clock.measure {
                _ = Document(parsing: markdown)
            }
            durations.append(duration)
        }

        let totalNanoseconds = durations.reduce(0) { $0 + $1.components.attoseconds / 1_000_000_000 }
        let avgNanoseconds = totalNanoseconds / Int64(iterations)

        print("📊 Repeated parsing (\(iterations) iterations):")
        print("   Document size: \(String(format: "%.2f", sizeKB)) KB")
        print("   Lines: \(lineCount)")
        print("   Total time: \(durations.reduce(Duration.zero, +))")
        print("   Average: \(Duration.nanoseconds(avgNanoseconds))")
        print("   Min: \(durations.min()!)")
        print("   Max: \(durations.max()!)")

        #expect(durations.count == iterations)
    }
}
