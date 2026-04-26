import Foundation

protocol FileSearchPolicy: Sendable {
    func shouldSearch(url: URL) -> Bool
}

struct DefaultFileSearchPolicy: FileSearchPolicy {
    func shouldSearch(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let textExtensions: Set<String> = [
            "md", "markdown", "txt", "text", "json", "yaml", "yml", "xml", "html", "css", "js",
            "ts", "swift", "py", "rb", "go", "rs",
        ]
        return textExtensions.contains(ext)
    }
}

struct GrepContentSearchAdapter: ContentSearchRepository {

    private let rootURL: URL
    private let contextLength: Int
    private let policy: FileSearchPolicy
    private let chunkSize: Int

    init(
        rootURL: URL,
        contextLength: Int = 80,
        policy: FileSearchPolicy = DefaultFileSearchPolicy(),
        chunkSize: Int = 64 * 1024
    ) {
        self.rootURL = rootURL
        self.contextLength = contextLength
        self.policy = policy
        self.chunkSize = chunkSize
    }

    func search(query: String) async throws -> [ContentSearchResult] {
        guard !query.isEmpty else { return [] }
        guard
            let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        var results: [ContentSearchResult] = []

        while let url = enumerator.nextObject() as? URL {
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            guard policy.shouldSearch(url: url) else { continue }

            guard let snippet = try searchFile(at: url, query: query) else { continue }

            let relativePath = url.standardizedFileURL.path
                .replacingOccurrences(of: rootURL.standardizedFileURL.path + "/", with: "")

            results.append(ContentSearchResult(path: relativePath, snippet: snippet))
        }

        return results
    }

    // MARK: - Private

    private func searchFile(at url: URL, query: String) throws -> ContentSearchSnippet? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let overlapSize = query.utf8.count - 1
        var carryOver = ""

        while true {
            let freshData = handle.readData(ofLength: chunkSize)
            guard !freshData.isEmpty else { break }

            guard let freshString = String(data: freshData, encoding: .utf8) else { break }
            let chunkString = carryOver + freshString

            if let range = chunkString.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
                return extractSnippet(from: chunkString, matchRange: range)
            }

            if chunkString.count > overlapSize {
                carryOver = String(chunkString.suffix(overlapSize))
            } else {
                carryOver = chunkString
            }
        }

        return nil
    }

    private func extractSnippet(from content: String, matchRange: Range<String.Index>)
        -> ContentSearchSnippet
    {
        let snippetStart =
            content.index(
                matchRange.lowerBound, offsetBy: -contextLength / 2, limitedBy: content.startIndex)
            ?? content.startIndex
        let snippetEnd =
            content.index(
                matchRange.upperBound, offsetBy: contextLength / 2, limitedBy: content.endIndex)
            ?? content.endIndex

        let prefix = snippetStart > content.startIndex ? "..." : ""
        let suffix = snippetEnd < content.endIndex ? "..." : ""

        // Build the snippet character by character, tracking where the match falls
        var text = prefix
        var matchStart: String.Index?
        var matchEnd: String.Index?
        var pastLeadingWhitespace = false

        for idx in content[snippetStart..<snippetEnd].indices {
            let ch = content[idx]
            let replacement: Character = ch == "\n" ? " " : ch

            // Skip leading whitespace
            if !pastLeadingWhitespace {
                if replacement.isWhitespace { continue }
                pastLeadingWhitespace = true
            }

            if idx == matchRange.lowerBound { matchStart = text.endIndex }
            if idx == matchRange.upperBound { matchEnd = text.endIndex }
            text.append(replacement)
        }
        // Handle upperBound at snippetEnd
        if matchEnd == nil, matchRange.upperBound <= snippetEnd {
            matchEnd = text.endIndex
        }

        // Trim trailing whitespace, but not past the match end
        let safeTrailBound = matchEnd ?? text.startIndex
        while text.endIndex > safeTrailBound, text.last?.isWhitespace == true {
            text.removeLast()
        }

        text += suffix

        return ContentSearchSnippet(
            text: text,
            matchRange: (matchStart ?? text.endIndex)..<(matchEnd ?? text.endIndex)
        )
    }
}
