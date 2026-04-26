import Foundation
import Testing

@testable import NoteBlobKit

struct NoteServiceTests {

    // MARK: - Helpers

    private let testFolder = Folder(repository: Repository(owner: "test", name: "repo"), defaultBranch: "main")

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoteServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeNoteService(root: URL) -> NoteService {
        NoteService(
            folder: testFolder,
            fileRepository: LocalFileAdapter(),
            localPathProvider: FixedPathProvider(path: root),
            repositoryAdapter: NoOpRepositoryAdapter(),
            contentSearchRepository: NoOpContentSearchRepository(),
            noteEventPublisher: NoteEventPublisher(),
            usageRepository: NoOpUsageRepository()
        )
    }

    private func createDir(at root: URL, path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func createFile(at root: URL, path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try "".write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - listFolderTree

    @Test func listFolderTreeReturnsEmptyForEmptyDirectory() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: .root)

        #expect(tree.isEmpty)
    }

    @Test func listFolderTreeIgnoresFiles() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createFile(at: root, path: "note.md")
        try createFile(at: root, path: "readme.txt")

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: .root)

        #expect(tree.isEmpty)
    }

    @Test func listFolderTreeReturnsFlatFolders() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createDir(at: root, path: "Alpha")
        try createDir(at: root, path: "Beta")
        try createDir(at: root, path: "Gamma")

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: .root)

        #expect(tree.count == 3)
        #expect(tree[0].name == "Alpha")
        #expect(tree[1].name == "Beta")
        #expect(tree[2].name == "Gamma")
        #expect(tree[0].children == nil)
        #expect(tree[1].children == nil)
        #expect(tree[2].children == nil)
    }

    @Test func listFolderTreeReturnsNestedStructure() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createDir(at: root, path: "A/B/C")
        try createDir(at: root, path: "A/D")

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: .root)

        #expect(tree.count == 1)

        let a = tree[0]
        #expect(a.name == "A")
        #expect(a.path == RelativePath("A"))
        #expect(a.children?.count == 2)

        let b = a.children?.first(where: { $0.name == "B" })
        #expect(b != nil)
        #expect(b?.path == RelativePath("A/B"))
        #expect(b?.children?.count == 1)

        let c = b?.children?.first
        #expect(c?.name == "C")
        #expect(c?.path == RelativePath("A/B/C"))
        #expect(c?.children == nil)

        let d = a.children?.first(where: { $0.name == "D" })
        #expect(d != nil)
        #expect(d?.path == RelativePath("A/D"))
        #expect(d?.children == nil)
    }

    @Test func listFolderTreeSortsFoldersAlphabetically() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createDir(at: root, path: "zebra")
        try createDir(at: root, path: "alpha")
        try createDir(at: root, path: "mango")

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: .root)

        let names = tree.map(\.name)
        #expect(names == ["alpha", "mango", "zebra"])
    }

    @Test func listFolderTreeMixesFoldersAndFilesKeepsOnlyFolders() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createDir(at: root, path: "docs")
        try createFile(at: root, path: "readme.md")
        try createDir(at: root, path: "docs/sub")
        try createFile(at: root, path: "docs/note.md")

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: .root)

        #expect(tree.count == 1)
        #expect(tree[0].name == "docs")
        #expect(tree[0].children?.count == 1)
        #expect(tree[0].children?.first?.name == "sub")
    }

    @Test func listFolderTreeFromSubpath() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createDir(at: root, path: "A/B/C")
        try createDir(at: root, path: "A/B/D")

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: RelativePath("A"))

        #expect(tree.count == 1)
        #expect(tree[0].name == "B")
        #expect(tree[0].children?.count == 2)

        let names = tree[0].children?.map(\.name)
        #expect(names == ["C", "D"])
    }

    // MARK: - searchItems (empty query)

    @Test func searchItemsEmptyQueryReturnsRecentlyModifiedFiles() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createFile(at: root, path: "a.md")
        try createFile(at: root, path: "b.md")

        let commits = [
            CommitInfo(id: "abc1234", message: "Update b", date: Date(), changedFiles: ["b.md"]),
            CommitInfo(id: "def5678", message: "Add a", date: Date().addingTimeInterval(-100), changedFiles: ["a.md"]),
        ]
        let repoAdapter = StubRepositoryAdapter(logResult: commits)
        let service = NoteService(
            folder: testFolder,
            fileRepository: LocalFileAdapter(),
            localPathProvider: FixedPathProvider(path: root),
            repositoryAdapter: repoAdapter,
            contentSearchRepository: NoOpContentSearchRepository(),
            noteEventPublisher: NoteEventPublisher(),
            usageRepository: NoOpUsageRepository()
        )

        let results = try await service.searchItems(in: testFolder, query: "")
        #expect(results.count == 2)
        #expect(results[0].item.name == "b.md")
        #expect(results[1].item.name == "a.md")
        #expect(results[0].snippet == nil)
    }

    @Test func searchItemsEmptyQuerySkipsHiddenFiles() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createFile(at: root, path: "visible.md")
        try createFile(at: root, path: ".hidden")

        let commits = [
            CommitInfo(id: "abc1234", message: "msg", date: Date(), changedFiles: [".hidden", "visible.md"]),
        ]
        let repoAdapter = StubRepositoryAdapter(logResult: commits)
        let service = NoteService(
            folder: testFolder,
            fileRepository: LocalFileAdapter(),
            localPathProvider: FixedPathProvider(path: root),
            repositoryAdapter: repoAdapter,
            contentSearchRepository: NoOpContentSearchRepository(),
            noteEventPublisher: NoteEventPublisher(),
            usageRepository: NoOpUsageRepository()
        )

        let results = try await service.searchItems(in: testFolder, query: "  ")
        #expect(results.count == 1)
        #expect(results[0].item.name == "visible.md")
    }

    @Test func searchItemsEmptyQuerySkipsDeletedFiles() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createFile(at: root, path: "exists.md")
        // "deleted.md" is NOT created on disk

        let commits = [
            CommitInfo(id: "abc1234", message: "msg", date: Date(), changedFiles: ["deleted.md", "exists.md"]),
        ]
        let repoAdapter = StubRepositoryAdapter(logResult: commits)
        let service = NoteService(
            folder: testFolder,
            fileRepository: LocalFileAdapter(),
            localPathProvider: FixedPathProvider(path: root),
            repositoryAdapter: repoAdapter,
            contentSearchRepository: NoOpContentSearchRepository(),
            noteEventPublisher: NoteEventPublisher(),
            usageRepository: NoOpUsageRepository()
        )

        let results = try await service.searchItems(in: testFolder, query: "")
        #expect(results.count == 1)
        #expect(results[0].item.name == "exists.md")
    }

    @Test func searchItemsEmptyQueryDeduplicatesFiles() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createFile(at: root, path: "a.md")

        let commits = [
            CommitInfo(id: "abc1234", message: "Update a", date: Date(), changedFiles: ["a.md"]),
            CommitInfo(id: "def5678", message: "Add a", date: Date().addingTimeInterval(-100), changedFiles: ["a.md"]),
        ]
        let repoAdapter = StubRepositoryAdapter(logResult: commits)
        let service = NoteService(
            folder: testFolder,
            fileRepository: LocalFileAdapter(),
            localPathProvider: FixedPathProvider(path: root),
            repositoryAdapter: repoAdapter,
            contentSearchRepository: NoOpContentSearchRepository(),
            noteEventPublisher: NoteEventPublisher(),
            usageRepository: NoOpUsageRepository()
        )

        let results = try await service.searchItems(in: testFolder, query: "")
        #expect(results.count == 1)
        #expect(results[0].item.name == "a.md")
    }

    // MARK: - listFolderTree

    @Test func listFolderTreeIgnoresHiddenFolders() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try createDir(at: root, path: ".git")
        try createDir(at: root, path: "visible")
        try createDir(at: root, path: ".hidden")

        let service = makeNoteService(root: root)
        let tree = try service.listFolderTree(in: testFolder, at: .root)

        #expect(tree.count == 1)
        #expect(tree[0].name == "visible")
    }
}

private struct FixedPathProvider: FolderLocalPathProvider {
    let path: URL

    func baseFoldersURL() -> URL { path }
    func localPath(for folder: Folder) -> URL { path }
}

private struct NoOpRepositoryAdapter: RepositoryAdapter {
    func cloneRepository(_ folder: Folder, credentials: Credentials) async throws {}
    func pull(_ folder: Folder) async throws {}
    func push(_ folder: Folder) async throws {}
    func pendingChanges(for folder: Folder) async throws -> [Change] { [] }
    func commitAll(in folder: Folder, message: String) async throws {}
    func currentBranch(for folder: Folder) async throws -> BranchInfo { BranchInfo(name: "main") }
    func createBranchAndSwitch(named: String, in folder: Folder) async throws {}
    func switchBranch(to name: String, in folder: Folder) async throws {}
    func deleteBranch(named: String, in folder: Folder) async throws {}
    func fetch(_ folder: Folder) async throws {}
    func aheadBehind(for folder: Folder, defaultBranch: String) async throws -> (ahead: Int, behind: Int) { (0, 0) }

    func hasUpstream(for folder: Folder) async throws -> Bool { false }
    func discardChanges(in folder: Folder) async throws {}
    func discardChange(in folder: Folder, path: RelativePath) async throws {}
    func diff(for folder: Folder, path: RelativePath) async throws -> FileDiff {
        FileDiff(path: path.value, hunks: [])
    }
    func log(for folder: Folder, options: LogOptions) async throws
        -> [CommitInfo]
    { [] }
}

private struct StubRepositoryAdapter: RepositoryAdapter {
    let logResult: [CommitInfo]

    func cloneRepository(_ folder: Folder, credentials: Credentials) async throws {}
    func pull(_ folder: Folder) async throws {}
    func push(_ folder: Folder) async throws {}
    func pendingChanges(for folder: Folder) async throws -> [Change] { [] }
    func commitAll(in folder: Folder, message: String) async throws {}
    func currentBranch(for folder: Folder) async throws -> BranchInfo { BranchInfo(name: "main") }
    func createBranchAndSwitch(named: String, in folder: Folder) async throws {}
    func switchBranch(to name: String, in folder: Folder) async throws {}
    func deleteBranch(named: String, in folder: Folder) async throws {}
    func fetch(_ folder: Folder) async throws {}
    func aheadBehind(for folder: Folder, defaultBranch: String) async throws -> (ahead: Int, behind: Int) { (0, 0) }

    func hasUpstream(for folder: Folder) async throws -> Bool { false }
    func discardChanges(in folder: Folder) async throws {}
    func discardChange(in folder: Folder, path: RelativePath) async throws {}
    func diff(for folder: Folder, path: RelativePath) async throws -> FileDiff {
        FileDiff(path: path.value, hunks: [])
    }
    func log(for folder: Folder, options: LogOptions) async throws -> [CommitInfo] {
        logResult
    }
}

private struct NoOpContentSearchRepository: ContentSearchRepository {
    func search(query: String) async throws -> [ContentSearchResult] { [] }
}

private struct NoOpUsageRepository: UsageRepository {
    func recordNoteAccess(folderID: String, path: RelativePath, name: String) {}
    func recentNotes(folderID: String, limit: Int) -> [NoteUsageEntry] { [] }
    func totalNoteAccessCount() -> Int { 0 }
    func incrementNoteAccessCount() {}
}
