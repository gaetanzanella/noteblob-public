import Foundation

public struct NoteSearchResult: Sendable {
    public let item: NoteItem
    public let parent: RelativePath
    public let snippet: ContentSearchSnippet?

    public init(item: NoteItem, snippet: ContentSearchSnippet? = nil) {
        self.item = item
        self.parent = item.path.parent
        self.snippet = snippet
    }
}
