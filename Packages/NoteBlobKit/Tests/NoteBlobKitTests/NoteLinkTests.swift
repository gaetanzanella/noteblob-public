import Foundation
import Testing

@testable import NoteBlobKit

@Suite struct NoteLinkTests {

    @Test func initFromSchemelessURLDerivesPath() {
        let link = NoteLink(url: URL(string: "folder/note.md")!)
        #expect(link?.path == RelativePath("folder/note.md"))
    }

    @Test func initFromURLDecodesPercentEncoding() {
        let link = NoteLink(url: URL(string: "folder/My%20Note.md")!)
        #expect(link?.path == RelativePath("folder/My Note.md"))
    }

    @Test func initFromHTTPURLReturnsNil() {
        #expect(NoteLink(url: URL(string: "https://example.com/foo")!) == nil)
    }

    @Test func initFromMailtoReturnsNil() {
        #expect(NoteLink(url: URL(string: "mailto:me@example.com")!) == nil)
    }

    @Test func encodedPathEncodesSpaces() {
        let link = NoteLink(path: RelativePath("folder/My Note.md"))
        #expect(link.encodedPath == "folder/My%20Note.md")
    }

    @Test func roundTripsThroughURL() {
        let original = NoteLink(path: RelativePath("a/b c/d.md"))
        let parsed = NoteLink(url: URL(string: original.encodedPath)!)
        #expect(parsed == original)
    }
}
