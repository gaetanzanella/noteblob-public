import Foundation

/// An inter-note markdown link. Stored on disk as plain relative markdown —
/// `[title](folder/note.md)` — with no custom scheme. A URL represents an
/// internal note reference iff it has no scheme; everything else (http,
/// https, mailto, …) is treated as external and handed to the system.
public struct NoteLink: Hashable, Sendable {

    public let path: RelativePath

    public init(path: RelativePath) {
        self.path = path
    }

    /// Parses an internal note link from a URL. Returns nil for URLs that
    /// carry any scheme (http, https, mailto, …).
    public init?(url: URL) {
        guard url.scheme == nil else { return nil }
        let raw = url.absoluteString
        let decoded = raw.removingPercentEncoding ?? raw
        self.path = RelativePath(decoded)
    }

    /// Percent-encoded path suitable as the destination of a markdown link.
    /// Round-trips with `init(url:)`.
    public var encodedPath: String {
        path.value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? path.value
    }
}
