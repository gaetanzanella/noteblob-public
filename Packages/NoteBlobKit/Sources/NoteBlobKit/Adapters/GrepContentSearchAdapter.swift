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

        let rawSnippet = String(content[snippetStart..<snippetEnd])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        let prefix = snippetStart > content.startIndex ? "..." : ""
        let suffix = snippetEnd < content.endIndex ? "..." : ""
        let text = prefix + rawSnippet + suffix

        let matchStartInSnippet = text.index(
            text.startIndex,
            offsetBy: prefix.count + content.distance(from: snippetStart, to: matchRange.lowerBound)
        )
        let matchEndInSnippet = text.index(
            matchStartInSnippet,
            offsetBy: content.distance(from: matchRange.lowerBound, to: matchRange.upperBound))

        return ContentSearchSnippet(
            text: text,
            matchRange: matchStartInSnippet..<matchEndInSnippet
        )
    }
}
