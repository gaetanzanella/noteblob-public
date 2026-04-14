import Foundation

public final class NoteService: Sendable {

    private let fileRepository: FileRepository
    private let localPathProvider: FolderLocalPathProvider
    private let repositoryAdapter: RepositoryAdapter
    private let contentSearchRepository: ContentSearchRepository
    private let noteEventPublisher: NoteEventPublisher
    private let usageRepository: UsageRepository
    private let folder: Folder

    init(
        folder: Folder,
        fileRepository: FileRepository,
        localPathProvider: FolderLocalPathProvider,
        repositoryAdapter: RepositoryAdapter,
        contentSearchRepository: ContentSearchRepository,
        noteEventPublisher: NoteEventPublisher,
        usageRepository: UsageRepository
    ) {
        self.folder = folder
        self.fileRepository = fileRepository
        self.localPathProvider = localPathProvider
        self.repositoryAdapter = repositoryAdapter
        self.contentSearchRepository = contentSearchRepository
        self.noteEventPublisher = noteEventPublisher
        self.usageRepository = usageRepository
    }

    public func listItems(in folder: Folder, at path: RelativePath) throws -> [NoteItem] {
        let url = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        let items = try fileRepository.listItems(at: url)
        return
            items
            .map { item in
                let itemPath = path.appending(item.name)
                if item.isDirectory {
                    return NoteItem.folder(.init(name: item.name, path: itemPath))
                } else {
                    return NoteItem.file(.init(name: item.name, path: itemPath))
                }
            }
            .sorted { lhs, rhs in
                if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    public func readNote(in folder: Folder, at path: RelativePath) throws -> String {
        let url = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        let content = try fileRepository.readFile(at: url)
        usageRepository.recordNoteAccess(
            folderID: folder.id,
            path: path,
            name: path.lastComponent
        )
        usageRepository.incrementNoteAccessCount()
        return content
    }

    public func fileURL(in folder: Folder, at path: RelativePath) -> URL {
        localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
    }

    public func fileExists(in folder: Folder, at path: RelativePath) -> Bool {
        let url = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func saveNote(in folder: Folder, at path: RelativePath, content: String) throws {
        let url = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        try fileRepository.writeFile(at: url, content: content)
    }

    @discardableResult
    public func createNote(in folder: Folder, at path: RelativePath, name: String) throws
        -> NoteFile
    {
        let fileName = name.hasSuffix(".md") ? name : "\(name).md"
        let url = localPathProvider.localPath(for: folder)
            .appendingPathComponent(path.value)
            .appendingPathComponent(fileName)
        try fileRepository.createFile(at: url)
        let notePath = path.appending(fileName)
        usageRepository.recordNoteAccess(
            folderID: folder.id,
            path: notePath,
            name: fileName
        )
        return NoteFile(name: fileName, path: notePath)
    }

    @discardableResult
    public func createFolder(in folder: Folder, at path: RelativePath, name: String) throws
        -> NoteFolder
    {
        let url = localPathProvider.localPath(for: folder)
            .appendingPathComponent(path.value)
            .appendingPathComponent(name)
        try fileRepository.createDirectory(at: url)
        let folderPath = path.appending(name)
        return NoteFolder(name: name, path: folderPath)
    }

    public func deleteNote(in folder: Folder, at path: RelativePath) throws {
        let url = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        try fileRepository.deleteItem(at: url)
        noteEventPublisher.publish(.didDelete(folder, path))
    }

    public func listFolderTree(in folder: Folder, at path: RelativePath) throws -> [FolderTreeNode]
    {
        let url = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        let items = try fileRepository.listItems(at: url)
        return
            try items
            .filter { $0.isDirectory }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { item in
                let itemPath = path.appending(item.name)
                let children = try listFolderTree(in: folder, at: itemPath)
                return FolderTreeNode(
                    name: item.name,
                    path: itemPath,
                    children: children.isEmpty ? nil : children
                )
            }
    }

    public func moveItem(in folder: Folder, at path: RelativePath, to destinationPath: RelativePath)
        throws
    {
        let sourceURL = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        let destinationURL = localPathProvider.localPath(for: folder)
            .appendingPathComponent(destinationPath.value)
            .appendingPathComponent(path.lastComponent)
        try fileRepository.moveItem(at: sourceURL, to: destinationURL)
    }

    public func moveItems(
        in folder: Folder, paths: [RelativePath], to destinationPath: RelativePath
    ) throws {
        guard isDirectory(in: folder, at: destinationPath) else { return }
        for path in paths {
            guard path != destinationPath, path.parent != destinationPath else { continue }
            try moveItem(in: folder, at: path, to: destinationPath)
        }
    }

    public func copyItem(in folder: Folder, at path: RelativePath, to destinationPath: RelativePath)
        throws
    {
        let sourceURL = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        let destinationURL = localPathProvider.localPath(for: folder)
            .appendingPathComponent(destinationPath.value)
            .appendingPathComponent(path.lastComponent)
        try fileRepository.copyItem(at: sourceURL, to: destinationURL)
    }

    public func copyItems(
        in folder: Folder, paths: [RelativePath], to destinationPath: RelativePath
    ) throws {
        guard isDirectory(in: folder, at: destinationPath) else { return }
        for path in paths {
            guard path != destinationPath, path.parent != destinationPath else { continue }
            try copyItem(in: folder, at: path, to: destinationPath)
        }
    }

    public func renameNote(in folder: Folder, at path: RelativePath, newName: String) throws {
        let sourceURL = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(newName)
        try fileRepository.moveItem(at: sourceURL, to: destinationURL)
    }

    public func searchItems(in folder: Folder, query: String) async throws -> [NoteSearchResult] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return try await recentlyModifiedFiles(in: folder, limit: 20)
        }

        var resultsByPath: [String: NoteSearchResult] = [:]

        // Content search
        let contentResults = try await contentSearchRepository.search(query: query)
        for result in contentResults {
            let path = RelativePath(result.path)
            let noteItem = NoteItem.file(.init(name: path.lastComponent, path: path))
            resultsByPath[result.path] = NoteSearchResult(item: noteItem, snippet: result.snippet)
        }

        // Filename search
        let url = localPathProvider.localPath(for: folder)
        let items = try fileRepository.searchItems(at: url, query: query)
        for item in items {
            let itemPath = RelativePath(item.relativePath)
            guard resultsByPath[item.relativePath] == nil else { continue }
            let noteItem: NoteItem
            if item.isDirectory {
                noteItem = .folder(.init(name: item.name, path: itemPath))
            } else {
                noteItem = .file(.init(name: item.name, path: itemPath))
            }
            resultsByPath[item.relativePath] = NoteSearchResult(item: noteItem)
        }

        return resultsByPath.values
            .sorted { lhs, rhs in
                if (lhs.snippet != nil) != (rhs.snippet != nil) { return lhs.snippet != nil }
                if lhs.item.isFolder != rhs.item.isFolder { return lhs.item.isFolder }
                return lhs.item.name.localizedStandardCompare(rhs.item.name) == .orderedAscending
            }
    }

    private func recentlyModifiedFiles(in folder: Folder, limit: Int) async throws
        -> [NoteSearchResult]
    {
        let commits = try await repositoryAdapter.log(
            for: folder, options: LogOptions(uniqueFilesLimit: limit)
        )
        var seen = Set<String>()
        var results: [NoteSearchResult] = []
        for commit in commits {
            for filePath in commit.changedFiles {
                guard !filePath.hasPrefix(".") else { continue }
                guard seen.insert(filePath).inserted else { continue }
                let path = RelativePath(filePath)
                guard fileExists(in: folder, at: path) else { continue }
                let noteItem = NoteItem.file(.init(name: path.lastComponent, path: path))
                results.append(NoteSearchResult(item: noteItem))
                if results.count >= limit { return results }
            }
        }
        return results
    }

    public func note(in folder: Folder, at path: RelativePath) async throws -> Note {
        let commits = try await repositoryAdapter.log(
            for: folder, options: LogOptions(limit: 1, path: path))
        return Note(latestChangeDate: commits.first?.date)
    }

    private func isDirectory(in folder: Folder, at path: RelativePath) -> Bool {
        let url = localPathProvider.localPath(for: folder).appendingPathComponent(path.value)
        return fileRepository.directoryExists(at: url)
    }

    public func shouldRequestReview() -> Bool {
        let count = usageRepository.totalNoteAccessCount()
        return count > 0 && count % 30 == 0
    }

    public func recentNotes(limit: Int = 5) -> [NoteFile] {
        let entries = usageRepository.recentNotes(folderID: folder.id, limit: limit)
        return entries.compactMap { entry in
            let path = RelativePath(entry.path)
            guard fileExists(in: folder, at: path) else { return nil }
            return NoteFile(name: entry.name, path: path)
        }
    }
}
