import Foundation

public enum NoteItem: Sendable, Identifiable, Hashable, Codable {
    case folder(NoteFolder)
    case file(NoteFile)

    public var id: String {
        switch self {
        case .folder(let folder): return "folder:\(folder.path.value)"
        case .file(let file): return "file:\(file.path.value)"
        }
    }

    public var name: String {
        switch self {
        case .folder(let folder): return folder.name
        case .file(let file): return file.name
        }
    }

    public var path: RelativePath {
        switch self {
        case .folder(let folder): return folder.path
        case .file(let file): return file.path
        }
    }

    public var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

// MARK: - NoteFolder

public struct NoteFolder: Sendable, Hashable, Codable {
    public let name: String
    public let path: RelativePath

    public init(name: String, path: RelativePath) {
        self.name = name
        self.path = path
    }
}

// MARK: - NoteFile

public struct NoteFile: Sendable, Hashable, Codable {
    public let name: String
    public let path: RelativePath
    public let type: FileType

    public init(name: String, path: RelativePath) {
        self.name = name
        self.path = path
        self.type = Self.fileType(for: name)
    }

    private static func fileType(for name: String) -> FileType {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown":
            return .markdown
        default:
            return .unknown
        }
    }
}

// MARK: - FileType

public enum FileType: Sendable, Hashable, Codable {
    case markdown
    case unknown
}
