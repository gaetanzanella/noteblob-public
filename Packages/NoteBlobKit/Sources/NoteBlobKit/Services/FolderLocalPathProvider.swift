import Foundation

public protocol FolderLocalPathProvider: Sendable {
    func baseFoldersURL() -> URL
    func localPath(for folder: Folder) -> URL
}
