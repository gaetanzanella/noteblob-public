import Testing

@testable import TextEditorKit

@Suite
struct URLLinkInterceptorTests {

    private let interceptor = URLLinkInterceptor()

    // MARK: - Happy path

    @Test @MainActor
    func pasteUrlOverSelectionCreatesMarkdownLink() {
        // previousText: "check this hello world"
        // user selects "hello", pastes "https://example.com"
        // newText: "check this https://example.com world"
        let ctx = makeContext(
            previousText: "check this hello world",
            newText: "check this https://example.com world",
            changedRange: 11..<16,
            replacementString: "https://example.com"
        )

        let edit = interceptor.intercept(ctx)

        #expect(edit != nil)
        // The URL at 11..<30 (19 chars) is rewritten to "[hello](https://example.com)" (28 chars).
        #expect(
            edit!.changes
                == [.replace(range: 11..<30, with: "[hello](https://example.com)")]
        )
        // Caret right after the closing paren.
        #expect(edit!.selection == 39..<39)
    }

    @Test @MainActor
    func pasteHttpsUrlIsAccepted() {
        let ctx = makeContext(
            previousText: "a",
            newText: "https://apple.com",
            changedRange: 0..<1,
            replacementString: "https://apple.com"
        )
        let edit = interceptor.intercept(ctx)
        #expect(edit != nil)
        #expect(edit!.changes == [.replace(range: 0..<17, with: "[a](https://apple.com)")])
    }

    @Test @MainActor
    func pasteHttpUrlIsAccepted() {
        let ctx = makeContext(
            previousText: "a",
            newText: "http://apple.com",
            changedRange: 0..<1,
            replacementString: "http://apple.com"
        )
        #expect(interceptor.intercept(ctx) != nil)
    }

    // MARK: - Not a URL / no-op

    @Test @MainActor
    func pasteOverEmptySelectionIsNoOp() {
        // Insertion, not replacement — no selection to wrap.
        let ctx = makeContext(
            previousText: "hello world",
            newText: "hello https://x.com world",
            changedRange: 6..<6,
            replacementString: "https://x.com"
        )
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func pastePlainTextOverSelectionIsNoOp() {
        let ctx = makeContext(
            previousText: "foo bar",
            newText: "foo baz",
            changedRange: 4..<7,
            replacementString: "baz"
        )
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func pasteWithoutSchemeIsNoOp() {
        let ctx = makeContext(
            previousText: "hello",
            newText: "example.com",
            changedRange: 0..<5,
            replacementString: "example.com"
        )
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func pasteWithUnsupportedSchemeIsNoOp() {
        let ctx = makeContext(
            previousText: "hi",
            newText: "mailto:a@b.com",
            changedRange: 0..<2,
            replacementString: "mailto:a@b.com"
        )
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func pasteMultilineUrlIsNoOp() {
        let ctx = makeContext(
            previousText: "hi",
            newText: "https://example.com\nmore",
            changedRange: 0..<2,
            replacementString: "https://example.com\nmore"
        )
        #expect(interceptor.intercept(ctx) == nil)
    }

    @Test @MainActor
    func pasteUrlWithEmbeddedSpaceIsNoOp() {
        let ctx = makeContext(
            previousText: "hi",
            newText: "https://example .com",
            changedRange: 0..<2,
            replacementString: "https://example .com"
        )
        #expect(interceptor.intercept(ctx) == nil)
    }

    // MARK: - Helpers

    @MainActor
    private func makeContext(
        previousText: String,
        newText: String,
        changedRange: Range<Int>,
        replacementString: String
    ) -> TypeContext {
        let editor = TextEditorKitTests.makeContext(
            newText,
            cursor: changedRange.lowerBound + replacementString.utf16.count
        )
        return TypeContext(
            previousText: previousText,
            newText: newText,
            changedRange: changedRange,
            replacementString: replacementString,
            editorContext: editor
        )
    }
}
