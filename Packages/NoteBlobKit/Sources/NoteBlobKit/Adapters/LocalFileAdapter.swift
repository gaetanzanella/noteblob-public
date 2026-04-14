import Foundation

final class LocalFileAdapter: FileRepository, Sendable {

    init() {}

    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    func listItems(at directoryURL: URL) throws -> [FileItem] {
        try mapError {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return try contents.map { url in
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                return FileItem(
                    name: url.lastPathComponent,
                    relativePath: url.lastPathComponent,
                    isDirectory: resourceValues.isDirectory ?? false
                )
            }
        }
    }

    func searchItems(at directoryURL: URL, query: String) throws -> [FileItem] {
        let lowercasedQuery = query.lowercased()
        var results: [FileItem] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent
            guard name.lowercased().contains(lowercasedQuery) else { continue }
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            let relativePath = url.standardizedFileURL.path
                .replacingOccurrences(of: directoryURL.standardizedFileURL.path + "/", with: "")
            results.append(FileItem(name: name, relativePath: relativePath, isDirectory: isDirectory))
        }
        return results
    }

    func readFile(at fileURL: URL) throws -> String {
        try mapError {
            try String(contentsOf: fileURL, encoding: .utf8)
        }
    }

    func writeFile(at fileURL: URL, content: String) throws {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func createFile(at fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func createDirectory(at directoryURL: URL) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func deleteItem(at itemURL: URL) throws {
        try FileManager.default.removeItem(at: itemURL)
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    // MARK: - Private

    private func mapError<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            throw FileRepositoryError.notFound
        } catch {
            throw error
        }
    }
}
