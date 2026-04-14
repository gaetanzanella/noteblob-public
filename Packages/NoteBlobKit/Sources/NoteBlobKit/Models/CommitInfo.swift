import Foundation

public struct CommitInfo: Sendable, Identifiable, Hashable {
    public let id: String
    public let message: String
    public let date: Date
    public let changedFiles: [String]

    public init(id: String, message: String, date: Date, changedFiles: [String] = []) {
        self.id = id
        self.message = message
        self.date = date
        self.changedFiles = changedFiles
    }
}

public struct LogOptions: Sendable {
    public var limit: Int
    public var downToRef: String?
    public var path: RelativePath?
    public var uniqueFilesLimit: Int?

    public init(
        limit: Int = 100,
        downToRef: String? = nil,
        path: RelativePath? = nil,
        uniqueFilesLimit: Int? = nil
    ) {
        self.limit = limit
        self.downToRef = downToRef
        self.path = path
        self.uniqueFilesLimit = uniqueFilesLimit
    }
}
