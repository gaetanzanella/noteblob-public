import Foundation

public enum FileRepositoryError: Error {
    case notFound
}

protocol FileRepository: Sendable {
    func directoryExists(at url: URL) -> Bool
    func listItems(at directoryURL: URL) throws -> [FileItem]
    func searchItems(at directoryURL: URL, query: String) throws -> [FileItem]
    func readFile(at fileURL: URL) throws -> String
    func writeFile(at fileURL: URL, content: String) throws
    func createFile(at fileURL: URL) throws
    func createDirectory(at directoryURL: URL) throws
    func deleteItem(at itemURL: URL) throws
    func moveItem(at sourceURL: URL, to destinationURL: URL) throws
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws
}

struct FileItem: Sendable {
    let name: String
    let relativePath: String
    let isDirectory: Bool
}
