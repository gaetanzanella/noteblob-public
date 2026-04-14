import Foundation

final class FileSystemFolderRepository: FolderRepository, Sendable {

    private let localPathProvider: FolderLocalPathProvider

    init(localPathProvider: FolderLocalPathProvider) {
        self.localPathProvider = localPathProvider
    }

    func list() throws -> [Folder] {
        let baseURL = localPathProvider.baseFoldersURL()
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let contents = try FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var folders: [Folder] = []
        for ownerURL in contents {
            guard isDirectory(ownerURL) else { continue }
            let ownerName = ownerURL.lastPathComponent

            if ownerName == "local" {
                let localFolders = try scanLocalFolders(at: ownerURL)
                folders.append(contentsOf: localFolders)
            } else {
                let repoFolders = try scanGitHubFolders(owner: ownerName, at: ownerURL)
                folders.append(contentsOf: repoFolders)
            }
        }

        return folders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func add(_ folder: Folder) throws {
        let path = localPathProvider.localPath(for: folder)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    }

    func remove(_ folder: Folder) throws {
        let path = localPathProvider.localPath(for: folder)
        try FileManager.default.removeItem(at: path)
    }

    // MARK: - Private

    private func scanLocalFolders(at localURL: URL) throws -> [Folder] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: localURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return contents
            .filter { isDirectory($0) }
            .map { Folder(localName: $0.lastPathComponent) }
    }

    private func scanGitHubFolders(owner: String, at ownerURL: URL) throws -> [Folder] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: ownerURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return contents
            .filter { isDirectory($0) && hasGitDirectory($0) }
            .map { Folder(repository: Repository(owner: owner, name: $0.lastPathComponent)) }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func hasGitDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent(".git").path,
            isDirectory: &isDir
        ) && isDir.boolValue
    }
}
