import Foundation
import Testing

@testable import NoteBlobKit

struct GrepContentSearchAdapterTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GrepSearchTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFile(at root: URL, path: String, content: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test func searchFindsContentMatch() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "hello.md", content: "Hello world, this is a test")
        try writeFile(at: root, path: "goodbye.md", content: "Goodbye cruel world")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "Hello")

        #expect(results.count == 1)
        #expect(results.first?.path == "hello.md")
        let snippet = try #require(results.first?.snippet)
        #expect(snippet.text.contains("Hello"))
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "Hello")
    }

    @Test func searchIsCaseInsensitive() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "Swift programming language")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "SWIFT")

        #expect(results.count == 1)
        let snippet = try #require(results.first?.snippet)
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "Swift")
    }

    @Test func searchIsDiacriticInsensitive() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "café résumé naïve")

        let adapter = GrepContentSearchAdapter(rootURL: root)

        let cafeResults = try await adapter.search(query: "cafe")
        #expect(cafeResults.count == 1)
        let cafeSnippet = try #require(cafeResults.first?.snippet)
        let cafeMatched = String(cafeSnippet.text[cafeSnippet.matchRange])
        #expect(cafeMatched == "café")

        let resumeResults = try await adapter.search(query: "resume")
        #expect(resumeResults.count == 1)
        let resumeSnippet = try #require(resumeResults.first?.snippet)
        let resumeMatched = String(resumeSnippet.text[resumeSnippet.matchRange])
        #expect(resumeMatched == "résumé")

        let naiveResults = try await adapter.search(query: "naive")
        #expect(naiveResults.count == 1)
        let naiveSnippet = try #require(naiveResults.first?.snippet)
        let naiveMatched = String(naiveSnippet.text[naiveSnippet.matchRange])
        #expect(naiveMatched == "naïve")
    }

    @Test func searchFindsMultipleFiles() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "a.md", content: "The quick brown fox")
        try writeFile(at: root, path: "b.md", content: "A fox jumped over the fence")
        try writeFile(at: root, path: "c.md", content: "No match here")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "fox")

        #expect(results.count == 2)
    }

    @Test func searchInSubdirectories() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "notes/deep/file.md", content: "deeply nested content")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "nested")

        #expect(results.count == 1)
        #expect(results.first?.path == "notes/deep/file.md")
    }

    @Test func searchReturnsSnippetWithContext() async throws {
        let root = try makeTempDir()
        let longContent = String(repeating: "padding ", count: 50) + "TARGET_WORD" + String(repeating: " padding", count: 50)
        try writeFile(at: root, path: "note.md", content: longContent)

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "TARGET_WORD")

        let snippet = try #require(results.first?.snippet)
        #expect(snippet.text.contains("TARGET_WORD"))
        #expect(snippet.text.hasPrefix("..."))
        #expect(snippet.text.hasSuffix("..."))
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "TARGET_WORD")
    }

    @Test func snippetRangeIsCorrectAtStartOfFile() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "Keyword at the start")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "Keyword")

        let snippet = try #require(results.first?.snippet)
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "Keyword")
        #expect(!snippet.text.hasPrefix("..."))
    }

    @Test func snippetRangeIsCorrectAtEndOfFile() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "text at the end Keyword")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "Keyword")

        let snippet = try #require(results.first?.snippet)
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "Keyword")
        #expect(!snippet.text.hasSuffix("..."))
    }

    @Test func snippetRangeWithMultibyteCharacters() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "café résumé naïve TARGET found")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "TARGET")

        let snippet = try #require(results.first?.snippet)
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "TARGET")
    }

    @Test func searchEmptyQueryReturnsEmpty() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "some content")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "")

        #expect(results.isEmpty)
    }

    @Test func searchSkipsHiddenFiles() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: ".hidden/secret.md", content: "secret content")
        try writeFile(at: root, path: "visible.md", content: "secret content")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "secret")

        #expect(results.count == 1)
        #expect(results.first?.path == "visible.md")
    }

    @Test func searchDiacriticMatchWithLeadingNewlines() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "\n\n  café latte\n\n")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "cafe")

        #expect(results.count == 1)
        let snippet = try #require(results.first?.snippet)
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "café")
    }

    @Test func searchDiacriticMatchAfterNewlines() async throws {
        let root = try makeTempDir()
        try writeFile(at: root, path: "note.md", content: "hello\n\nworld\n\nrésumé of the day")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "resume")

        #expect(results.count == 1)
        let snippet = try #require(results.first?.snippet)
        let matched = String(snippet.text[snippet.matchRange])
        #expect(matched == "résumé")
    }

    @Test func searchSkipsBinaryFiles() async throws {
        let root = try makeTempDir()
        let binaryURL = root.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00]).write(to: binaryURL)
        try writeFile(at: root, path: "note.md", content: "text content")

        let adapter = GrepContentSearchAdapter(rootURL: root)
        let results = try await adapter.search(query: "content")

        #expect(results.count == 1)
        #expect(results.first?.path == "note.md")
    }

}
