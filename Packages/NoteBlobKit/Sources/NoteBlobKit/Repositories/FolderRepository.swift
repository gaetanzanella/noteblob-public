import Foundation

protocol FolderRepository: Sendable {
    func list() throws -> [Folder]
    func add(_ folder: Folder) throws
    func remove(_ folder: Folder) throws
}
