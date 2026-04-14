import Foundation

public struct NoteUsageEntry: Sendable, Codable {
    public let folderID: String
    public let path: String
    public let name: String
    public let date: Date

    public init(folderID: String, path: String, name: String, date: Date) {
        self.folderID = folderID
        self.path = path
        self.name = name
        self.date = date
    }
}

protocol UsageRepository: Sendable {
    func recordNoteAccess(folderID: String, path: RelativePath, name: String)
    func recentNotes(folderID: String, limit: Int) -> [NoteUsageEntry]
    func totalNoteAccessCount() -> Int
    func incrementNoteAccessCount()
}
