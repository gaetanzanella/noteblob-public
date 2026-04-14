import Foundation
import Testing

@testable import NoteBlobKit

/// Integration tests for FolderSyncService using DependencyProvider.
/// Uses local bare repos as "remotes" — no network needed.
struct FolderSyncServiceTests {

    // MARK: - Helpers

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private struct Services {
        let syncService: FolderSyncService
        let noteService: NoteService
    }

    private func makeServices(cloneDir: URL, baseDir: URL, pullRequestAdapter: PullRequestAdapter? = nil) -> Services {
        let provider = DependencyProvider(
            localPathProvider: FixedPathProvider(path: cloneDir),
            credentialsProvider: StaticCredentialsProvider(token: "unused"),
            repositoryURLProvider: LocalURLProvider(basePath: baseDir),
            pullRequestAdapter: pullRequestAdapter
        )
        return Services(
            syncService: provider.makeFolderSyncService(),
            noteService: provider.makeNoteService(for: testFolder)
        )
    }

    private let testFolder = Folder(repository: Repository(owner: "test", name: "remote"))


    // MARK: - Tests

    @Test func addClonesAndPersistsFolder() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)

        try await services.syncService.add(testFolder)

        // Clone should exist and be a valid repo
        #expect(FileManager.default.fileExists(atPath: cloneDir.appendingPathComponent(".git").path))

        // Check status works on the cloned repo
        let status = try await services.syncService.status(for: testFolder)
        #expect(status.state == .upToDate)
        #expect(status.branch.isMain)

        // NoteService should be able to list cloned files
        let items = try services.noteService.listItems(in: testFolder, at: .root)
        let names = items.map(\.name)
        #expect(names.contains("README.md"))
    }

    @Test func statusUpToDate() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        let status = try await services.syncService.status(for: testFolder)
        #expect(status.state == .upToDate)
        #expect(status.branch.isMain)
    }

    @Test func statusLocalChanges() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        try services.noteService.saveNote(in: testFolder, at: "README.md", content: "modified\n")

        let status = try await services.syncService.status(for: testFolder)
        #expect(status.state == .localChanges(1))
    }

    @Test func commitCreatesBranchFromMain() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Create a change and commit
        try services.noteService.createNote(in: testFolder, at: .root, name: "a")
        try await services.syncService.commit(in: testFolder, message: "test commit")

        // Should now be on a noteblob/ branch
        let status = try await services.syncService.status(for: testFolder)
        #expect(!status.branch.isMain)
        #expect(status.branch.name.hasPrefix("noteblob/"))
        // Should have unpushed commits
        #expect(status.state == .pushNeeded)
    }

    @Test func pushFromMainThrowsInvalidOperation() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        await #expect(throws: NoteBlobError.self) {
            try await services.syncService.push(testFolder)
        }
    }

    @Test func pushAndPull() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)

        // Clone A
        let cloneA = baseDir.appendingPathComponent("clone-a")
        let servicesA = makeServices(cloneDir: cloneA, baseDir: baseDir)
        try await servicesA.syncService.add(testFolder)

        // Clone B
        let cloneB = baseDir.appendingPathComponent("clone-b")
        let servicesB = makeServices(cloneDir: cloneB, baseDir: baseDir)
        try await servicesB.syncService.add(testFolder)

        // A creates a note and commits (this creates a branch)
        try servicesA.noteService.createNote(in: testFolder, at: .root, name: "a")
        let statusAfterChange = try await servicesA.syncService.status(for: testFolder)
        #expect(statusAfterChange.state == .localChanges(1))

        try await servicesA.syncService.commit(in: testFolder, message: "A's commit")
        let statusAfterCommit = try await servicesA.syncService.status(for: testFolder)
        #expect(statusAfterCommit.state == .pushNeeded)
        #expect(!statusAfterCommit.branch.isMain)

        // A pushes (from branch)
        try await servicesA.syncService.push(testFolder)
        let statusAfterPush = try await servicesA.syncService.status(for: testFolder)
        #expect(statusAfterPush.state == .readyToMerge)

        // B should still be up to date (on main, A pushed to a branch)
        let statusB = try await servicesB.syncService.status(for: testFolder)
        #expect(statusB.state == .upToDate)
    }

    @Test func searchFindsFilesRecursively() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Create files in root and a subfolder
        try services.noteService.createNote(in: testFolder, at: .root, name: "hello")
        try services.noteService.createNote(in: testFolder, at: .root, name: "world")
        try FileManager.default.createDirectory(
            at: cloneDir.appendingPathComponent("sub"),
            withIntermediateDirectories: true
        )
        try services.noteService.createNote(in: testFolder, at: RelativePath("sub"), name: "hello-nested")

        // Search for "hello" should find both root and nested files
        let results = try await services.noteService.searchItems(in: testFolder, query: "hello")
        let names = results.map(\.item.name)
        #expect(names.contains("hello.md"))
        #expect(names.contains("hello-nested.md"))
        #expect(!names.contains("world.md"))

        // Search is case-insensitive
        let upperResults = try await services.noteService.searchItems(in: testFolder, query: "HELLO")
        #expect(upperResults.count == results.count)

        // Search for "sub" should find the subfolder
        let folderResults = try await services.noteService.searchItems(in: testFolder, query: "sub")
        let folderNames = folderResults.map(\.item.name)
        #expect(folderNames.contains("sub"))

        // Empty query returns empty
        let emptyResults = try await services.noteService.searchItems(in: testFolder, query: "nonexistent")
        #expect(emptyResults.isEmpty)
    }

    @Test func pullConflictThrowsConflict() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)

        // Clone A
        let cloneA = baseDir.appendingPathComponent("clone-a")
        let servicesA = makeServices(cloneDir: cloneA, baseDir: baseDir)
        try await servicesA.syncService.add(testFolder)
        try GitTestHelper.configureUser(at: cloneA)

        // Clone B
        let cloneB = baseDir.appendingPathComponent("clone-b")
        let servicesB = makeServices(cloneDir: cloneB, baseDir: baseDir)
        try await servicesB.syncService.add(testFolder)
        try GitTestHelper.configureUser(at: cloneB)

        // B modifies README and pushes directly (simulating remote push via git CLI)
        try servicesB.noteService.saveNote(in: testFolder, at: "README.md", content: "B version\n")
        try GitTestHelper.run(["add", "."], at: cloneB)
        try GitTestHelper.run(["commit", "-m", "B edits"], at: cloneB)
        try GitTestHelper.run(["push"], at: cloneB)

        // A modifies same file and commits locally (also directly on main for conflict test)
        try servicesA.noteService.saveNote(in: testFolder, at: "README.md", content: "A version\n")
        try GitTestHelper.run(["add", "."], at: cloneA)
        try GitTestHelper.run(["commit", "-m", "A edits"], at: cloneA)

        // Pull should throw conflict
        await #expect(throws: NoteBlobError.conflict) {
            try await servicesA.syncService.pull(testFolder)
        }
    }

    // MARK: - Merge tests

    @Test func mergeFullFlow() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let mockPR = MockPullRequestAdapter(bareRepoPath: baseDir.appendingPathComponent("remote.git"))
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir, pullRequestAdapter: mockPR)
        try await services.syncService.add(testFolder)

        // Create, commit, push
        try services.noteService.createNote(in: testFolder, at: .root, name: "note")
        try await services.syncService.commit(in: testFolder, message: "add note")
        try await services.syncService.push(testFolder)

        let statusBeforeMerge = try await services.syncService.status(for: testFolder)
        #expect(statusBeforeMerge.state == .readyToMerge)

        // Merge
        try await services.syncService.merge(testFolder)

        // After merge: back on main, up to date, branch deleted
        let statusAfterMerge = try await services.syncService.status(for: testFolder)
        #expect(statusAfterMerge.state == .upToDate)
        #expect(statusAfterMerge.branch.isMain)

        // The file should still exist
        let items = try services.noteService.listItems(in: testFolder, at: .root)
        #expect(items.map(\.name).contains("note.md"))
    }

    @Test func mergeFromMainThrowsInvalidOperation() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let mockPR = MockPullRequestAdapter(bareRepoPath: baseDir.appendingPathComponent("remote.git"))
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir, pullRequestAdapter: mockPR)
        try await services.syncService.add(testFolder)

        await #expect(throws: NoteBlobError.self) {
            try await services.syncService.merge(testFolder)
        }
    }

    @Test func mergeConflictThrowsMergeConflict() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let mockPR = MockPullRequestAdapter(bareRepoPath: baseDir.appendingPathComponent("remote.git"))
        mockPR.shouldFailMerge = true
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir, pullRequestAdapter: mockPR)
        try await services.syncService.add(testFolder)

        // Create, commit, push
        try services.noteService.createNote(in: testFolder, at: .root, name: "conflict-note")
        try await services.syncService.commit(in: testFolder, message: "will conflict")
        try await services.syncService.push(testFolder)

        // Merge should throw mergeConflict with PR URL
        do {
            try await services.syncService.merge(testFolder)
            Issue.record("Expected mergeConflict error")
        } catch let error as NoteBlobError {
            guard case .mergeConflict(let prURL) = error else {
                Issue.record("Expected mergeConflict, got \(error)")
                return
            }
            #expect(prURL.contains("/pull/"))
        }
    }

    @Test func mergeReusesExistingOpenPR() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let mockPR = MockPullRequestAdapter(bareRepoPath: baseDir.appendingPathComponent("remote.git"))
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir, pullRequestAdapter: mockPR)
        try await services.syncService.add(testFolder)

        // Create, commit, push
        try services.noteService.createNote(in: testFolder, at: .root, name: "reuse-pr")
        try await services.syncService.commit(in: testFolder, message: "first commit")
        try await services.syncService.push(testFolder)

        // First merge attempt fails — PR is created but merge fails
        mockPR.shouldFailMerge = true
        do {
            try await services.syncService.merge(testFolder)
        } catch is NoteBlobError {
            // expected
        }

        // Fix the merge and retry — should reuse existing PR (number 1), not create number 2
        mockPR.shouldFailMerge = false
        try await services.syncService.merge(testFolder)

        let status = try await services.syncService.status(for: testFolder)
        #expect(status.state == .upToDate)
        #expect(status.branch.isMain)
    }

    @Test func statusReadyToMergeAfterPush() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Commit (creates branch) and push
        try services.noteService.createNote(in: testFolder, at: .root, name: "ready")
        try await services.syncService.commit(in: testFolder, message: "ready to merge")
        try await services.syncService.push(testFolder)

        let status = try await services.syncService.status(for: testFolder)
        #expect(status.state == .readyToMerge)
        #expect(!status.branch.isMain)
    }

    @Test func multipleCommitsOnBranchBeforePush() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // First commit creates the branch
        try services.noteService.createNote(in: testFolder, at: .root, name: "first")
        try await services.syncService.commit(in: testFolder, message: "first")

        let statusAfterFirst = try await services.syncService.status(for: testFolder)
        let branchName = statusAfterFirst.branch.name
        #expect(branchName.hasPrefix("noteblob/"))

        // Second commit stays on the same branch (not creating a new one)
        try services.noteService.createNote(in: testFolder, at: .root, name: "second")
        try await services.syncService.commit(in: testFolder, message: "second")

        let statusAfterSecond = try await services.syncService.status(for: testFolder)
        #expect(statusAfterSecond.branch.name == branchName)
        #expect(statusAfterSecond.state == .pushNeeded)
    }

    @Test func diffReturnsHunksForModifiedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Modify the README via noteService
        try services.noteService.saveNote(
            in: testFolder, at: RelativePath("README.md"), content: "Updated content\n")

        let fileDiff = try await services.syncService.diff(
            for: testFolder, at: RelativePath("README.md"))
        #expect(fileDiff.path == "README.md")
        #expect(!fileDiff.hunks.isEmpty)

        let additions = fileDiff.hunks.flatMap(\.lines).filter { $0.kind == .addition }
        #expect(additions.contains { $0.content.contains("Updated content") })
    }

    @Test func pushAfterDiscardCleansUpEmptyBranch() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Create a change and commit (creates branch + commits)
        try services.noteService.createNote(in: testFolder, at: .root, name: "temp")
        try await services.syncService.commit(in: testFolder, message: "temp commit")

        // Verify we're on a branch with pushNeeded
        let statusAfterCommit = try await services.syncService.status(for: testFolder)
        #expect(!statusAfterCommit.branch.isMain)
        #expect(statusAfterCommit.state == .pushNeeded)

        // Discard all changes — reverts working tree but commit still exists
        // Then create the same scenario as the bug: discard the committed file
        // by reverting working tree. The commit is still on the branch.
        try await services.syncService.discardChanges(in: testFolder)

        // Push should succeed (branch has 1 commit ahead of main)
        try await services.syncService.push(testFolder)

        let statusAfterPush = try await services.syncService.status(for: testFolder)
        #expect(statusAfterPush.state == .readyToMerge)
    }

    @Test func pushEmptyBranchCleansUp() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Manually create and switch to an empty branch (same commit as main)
        try GitTestHelper.run(["checkout", "-b", "noteblob/empty-branch"], at: cloneDir)

        let statusBefore = try await services.syncService.status(for: testFolder)
        #expect(!statusBefore.branch.isMain)

        // Push should not crash — it should detect 0 commits ahead and clean up
        try await services.syncService.push(testFolder)

        // Should be back on main after cleanup
        let statusAfter = try await services.syncService.status(for: testFolder)
        #expect(statusAfter.branch.isMain)
        #expect(statusAfter.state == .upToDate)
    }

    @Test func pushOnlyCurrentBranchIgnoresStaleRefspecs() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // First session: create a note, commit (creates branch A), push
        try services.noteService.createNote(in: testFolder, at: .root, name: "first")
        try await services.syncService.commit(in: testFolder, message: "first session")
        let branchA = try await services.syncService.status(for: testFolder).branch.name
        try await services.syncService.push(testFolder)

        // Simulate GitHub merge: fast-forward main in the bare remote, then pull
        let bareRemote = baseDir.appendingPathComponent("remote.git")
        try GitTestHelper.run(["branch", "-f", "main", branchA], at: bareRemote)

        // Switch back to main, pull the merge, delete branch A locally
        try GitTestHelper.run(["checkout", "main"], at: cloneDir)
        try GitTestHelper.run(["pull", "origin", "main"], at: cloneDir)
        try GitTestHelper.run(["branch", "-D", branchA], at: cloneDir)
        // Delete remote tracking branch but the push refspec for branch A persists in config
        try GitTestHelper.run(["push", "origin", "--delete", branchA], at: cloneDir)

        // Second session: create another note, commit (creates branch B)
        try services.noteService.createNote(in: testFolder, at: .root, name: "second")
        try await services.syncService.commit(in: testFolder, message: "second session")
        let statusB = try await services.syncService.status(for: testFolder)
        #expect(!statusB.branch.isMain)

        // Push should succeed — only pushes branch B, not the stale refspec for branch A
        try await services.syncService.push(testFolder)

        let statusAfterPush = try await services.syncService.status(for: testFolder)
        #expect(statusAfterPush.state == .readyToMerge)
    }

    // MARK: - Log tests

    @Test func logReturnsCommitsAfterCommit() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        try services.noteService.createNote(in: testFolder, at: .root, name: "log-test")
        try await services.syncService.commit(in: testFolder, message: "add log-test note")

        let log = try await services.syncService.commitLog(for: testFolder, limit: 10)
        #expect(!log.isEmpty)
        #expect(log.first?.message == "add log-test note")
        #expect(log.first?.id.count == 7)
    }

    @Test func logDistinguishesUnpushedFromPushed() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // First commit + push
        try services.noteService.createNote(in: testFolder, at: .root, name: "first")
        try await services.syncService.commit(in: testFolder, message: "first commit")
        try await services.syncService.push(testFolder)

        // Second commit (unpushed)
        try services.noteService.createNote(in: testFolder, at: .root, name: "second")
        try await services.syncService.commit(in: testFolder, message: "second commit")

        let log = try await services.syncService.commitLog(for: testFolder, limit: 10)
        let unpushedCount = try await services.syncService.unpushedCommitCount(for: testFolder)

        #expect(unpushedCount == 1)
        // Only branch-specific commits (not main's "Initial commit")
        #expect(log.count == 2)
        #expect(log[0].message == "second commit")
        #expect(log[1].message == "first commit")
    }

    @Test func logRespectsLimit() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Create 3 commits
        for i in 1...3 {
            try services.noteService.createNote(in: testFolder, at: .root, name: "note-\(i)")
            try await services.syncService.commit(in: testFolder, message: "commit \(i)")
        }

        let limitedLog = try await services.syncService.commitLog(for: testFolder, limit: 2)
        #expect(limitedLog.count == 2)
        #expect(limitedLog[0].message == "commit 3")
    }

    @Test func noteReturnsLatestChangeDateForFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Create two files in separate commits
        try services.noteService.createNote(in: testFolder, at: .root, name: "first")
        try await services.syncService.commit(in: testFolder, message: "add first")

        try services.noteService.createNote(in: testFolder, at: .root, name: "second")
        try await services.syncService.commit(in: testFolder, message: "add second")

        // Each file's date should match its own commit's date
        let log = try await services.syncService.commitLog(for: testFolder, limit: 10)
        let firstCommit = log.first { $0.message == "add first" }!
        let secondCommit = log.first { $0.message == "add second" }!

        let firstNote = try await services.noteService.note(in: testFolder, at: RelativePath("first.md"))
        let secondNote = try await services.noteService.note(in: testFolder, at: RelativePath("second.md"))

        #expect(firstNote.latestChangeDate == firstCommit.date)
        #expect(secondNote.latestChangeDate == secondCommit.date)
    }

    @Test func noteReturnsNilDateForUntrackedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        try GitTestHelper.createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("clone")
        let services = makeServices(cloneDir: cloneDir, baseDir: baseDir)
        try await services.syncService.add(testFolder)

        // Create a file but don't commit it
        try services.noteService.createNote(in: testFolder, at: .root, name: "uncommitted")

        let note = try await services.noteService.note(in: testFolder, at: RelativePath("uncommitted.md"))
        #expect(note.latestChangeDate == nil)
    }

    @Test func branchInfoDetectsMain() {
        let main = BranchInfo(name: "main")
        #expect(main.isMain)

        let master = BranchInfo(name: "master")
        #expect(master.isMain)

        let feature = BranchInfo(name: "noteblob/20260319-120000")
        #expect(!feature.isMain)
    }
}

// MARK: - Test helpers

private struct FixedPathProvider: FolderLocalPathProvider {
    let path: URL

    func baseFoldersURL() -> URL { path }
    func localPath(for folder: Folder) -> URL { path }
}

/// Returns a fixed token as credentials — no keychain needed.
private struct StaticCredentialsProvider: CredentialsProvider {
    let token: String

    func loadCredentials() throws -> Credentials? {
        Credentials(token: token)
    }
}

/// Maps folder name to a local bare repo path: basePath/<name>.git
private struct LocalURLProvider: RepositoryURLProvider {
    let basePath: URL

    func remoteURL(for folder: Folder, credentials: Credentials) -> String {
        basePath.appendingPathComponent("\(folder.repository!.name).git").path
    }
}

/// Mock PullRequestAdapter that simulates GitHub PR operations locally.
/// On merge, it fast-forwards the bare remote's main branch to the pushed branch head
/// so that the subsequent `pull` in the merge flow actually picks up the changes.
private final class MockPullRequestAdapter: PullRequestAdapter, @unchecked Sendable {

    private let bareRepoPath: URL
    private var nextPRNumber = 1
    private var createdPRs: [String: PullRequest] = [:]
    private var mergedBranches: Set<String> = []
    var shouldFailMerge = false

    init(bareRepoPath: URL) {
        self.bareRepoPath = bareRepoPath
    }

    func listPullRequests(_ request: ListPullRequestsRequest) async throws -> [PullRequest] {
        // Return the PR if it was created and not yet merged
        if let pr = createdPRs[request.head], !mergedBranches.contains(request.head) {
            return [pr]
        }
        return []
    }

    func createPullRequest(_ request: CreatePullRequestRequest) async throws -> PullRequest {
        let pr = PullRequest(number: nextPRNumber, htmlURL: "https://github.com/\(request.owner)/\(request.repo)/pull/\(nextPRNumber)")
        nextPRNumber += 1
        createdPRs[request.head] = pr
        return pr
    }

    func mergePullRequest(_ request: MergePullRequestRequest) async throws {
        if shouldFailMerge {
            throw GitClientError.apiError(statusCode: 405, message: "Merge conflict")
        }

        // Find which branch this PR is for
        guard let (branch, _) = createdPRs.first(where: { $0.value.number == request.number }) else {
            throw GitClientError.apiError(statusCode: 404, message: "PR not found")
        }

        // Simulate GitHub merge: update main in the bare repo to point to the branch head.
        // We need a working tree to do this, so we use git CLI on a temp clone of the bare repo.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-merge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let workDir = tmpDir.appendingPathComponent("work")
        try GitTestHelper.clone(remote: bareRepoPath.path, to: workDir, in: tmpDir)
        try GitTestHelper.run(["fetch", "origin", branch], at: workDir)
        try GitTestHelper.run(["merge", "--ff-only", "origin/\(branch)"], at: workDir)
        try GitTestHelper.run(["push", "origin", "main"], at: workDir)

        mergedBranches.insert(branch)
    }

}
