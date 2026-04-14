import Foundation
import Testing

@testable import NoteBlobKit

/// Integration tests for SwiftGitXClient using real git repos on disk.
/// Uses a local bare repo as the "remote" — no network needed.
struct SwiftGitXClientTests {

    let client = SwiftGitXClient()

    // MARK: - Helpers

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoteBlobKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func createBareRemote(in baseDir: URL) throws -> (bare: URL, remoteURL: String) {
        let bare = try GitTestHelper.createBareRemote(in: baseDir)
        return (bare, bare.path)
    }

    // MARK: - Tests

    @Test func clone() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")

        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        let readme = cloneDir.appendingPathComponent("README.md")
        #expect(FileManager.default.fileExists(atPath: readme.path))

        let content = try String(contentsOf: readme, encoding: .utf8)
        #expect(content == "# Test Repo\n")
    }

    @Test func pendingChangesAndCommit() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // No changes initially
        let initial = try await client.pendingChanges(at: cloneDir)
        #expect(initial.isEmpty)

        // Modify a file
        try "# Updated\n".write(
            to: cloneDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let changes = try await client.pendingChanges(at: cloneDir)
        #expect(changes.count == 1)
        #expect(changes.first == .modified(path: "README.md"))

        // Add a new file
        try "Hello\n".write(
            to: cloneDir.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)

        let changes2 = try await client.pendingChanges(at: cloneDir)
        #expect(changes2.count == 2)

        // Commit
        try await client.commitAll(at: cloneDir, message: "Update files")

        let afterCommit = try await client.pendingChanges(at: cloneDir)
        #expect(afterCommit.isEmpty)
    }

    @Test func push() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (bare, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Commit a change
        try "new file\n".write(
            to: cloneDir.appendingPathComponent("new.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add new.md")

        // Push
        try await client.push(at: cloneDir)

        // Verify: clone from bare again and check the file exists
        let verifyDir = baseDir.appendingPathComponent("verify-clone")
        try GitTestHelper.clone(remote: bare.path, to: verifyDir, in: baseDir)
        #expect(
            FileManager.default.fileExists(atPath: verifyDir.appendingPathComponent("new.md").path))
    }

    @Test func pullFastForward() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)

        // Clone A (our client)
        let cloneA = baseDir.appendingPathComponent("clone-a")
        try await client.clone(remoteURL: remoteURL, to: cloneA)

        // Clone B (simulated second user via CLI)
        let cloneB = baseDir.appendingPathComponent("clone-b")
        try GitTestHelper.clone(remote: remoteURL, to: cloneB, in: baseDir)

        // User B makes a change and pushes
        try "From user B\n".write(
            to: cloneB.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try GitTestHelper.run(["add", "."], at: cloneB)
        try GitTestHelper.run(["commit", "-m", "B's commit"], at: cloneB)
        try GitTestHelper.run(["push"], at: cloneB)

        // Client A pulls — should fast-forward
        try await client.pull(at: cloneA)

        let bFile = cloneA.appendingPathComponent("b.md")
        #expect(FileManager.default.fileExists(atPath: bFile.path))

        let content = try String(contentsOf: bFile, encoding: .utf8)
        #expect(content == "From user B\n")
    }

    @Test func pullRebase() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)

        // Clone A (our client)
        let cloneA = baseDir.appendingPathComponent("clone-a")
        try await client.clone(remoteURL: remoteURL, to: cloneA)

        // Clone B (second user)
        let cloneB = baseDir.appendingPathComponent("clone-b")
        try GitTestHelper.clone(remote: remoteURL, to: cloneB, in: baseDir)

        // User B commits and pushes
        try "From B\n".write(
            to: cloneB.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try GitTestHelper.run(["add", "."], at: cloneB)
        try GitTestHelper.run(["commit", "-m", "B's commit"], at: cloneB)
        try GitTestHelper.run(["push"], at: cloneB)

        // User A commits locally (diverging)
        try "From A\n".write(
            to: cloneA.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneA, message: "A's commit")

        // Pull --rebase: should replay A's commit on top of B's
        try await client.pull(at: cloneA)

        // Both files should exist
        #expect(FileManager.default.fileExists(atPath: cloneA.appendingPathComponent("a.md").path))
        #expect(FileManager.default.fileExists(atPath: cloneA.appendingPathComponent("b.md").path))

        // Verify linear history (no merge commits) — should be 3 commits: initial, B's, A's
        let log = try GitTestHelper.run(["log", "--oneline"], at: cloneA)
        let commits = log.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(commits.count == 3)

        // A's commit should be on top (most recent)
        #expect(commits[0].contains("A's commit"))
        #expect(commits[1].contains("B's commit"))
    }

    @Test func pullUpToDate() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Pull when already up to date — should be a no-op
        try await client.pull(at: cloneDir)

        // Verify still works
        let changes = try await client.pendingChanges(at: cloneDir)
        #expect(changes.isEmpty)
    }

    @Test func isBehindRemote() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)

        let cloneA = baseDir.appendingPathComponent("clone-a")
        try await client.clone(remoteURL: remoteURL, to: cloneA)

        let cloneB = baseDir.appendingPathComponent("clone-b")
        try GitTestHelper.clone(remote: remoteURL, to: cloneB, in: baseDir)

        // Initially not behind
        try await client.fetch(at: cloneA)
        let (_, initialBehind) = try await client.aheadBehind(at: cloneA)
        #expect(initialBehind == 0)

        // User B pushes a change
        try "change\n".write(
            to: cloneB.appendingPathComponent("change.md"), atomically: true, encoding: .utf8)
        try GitTestHelper.run(["add", "."], at: cloneB)
        try GitTestHelper.run(["commit", "-m", "B pushes"], at: cloneB)
        try GitTestHelper.run(["push"], at: cloneB)

        // Now A should be behind
        try await client.fetch(at: cloneA)
        let (_, behind) = try await client.aheadBehind(at: cloneA)
        #expect(behind > 0)
    }

    @Test func pullConflictThrowsConflictError() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)

        // Clone A (our client)
        let cloneA = baseDir.appendingPathComponent("clone-a")
        try await client.clone(remoteURL: remoteURL, to: cloneA)

        // Clone B (second user)
        let cloneB = baseDir.appendingPathComponent("clone-b")
        try GitTestHelper.clone(remote: remoteURL, to: cloneB, in: baseDir)

        // Both users modify the SAME file with different content
        try "User B version\n".write(
            to: cloneB.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try GitTestHelper.run(["add", "."], at: cloneB)
        try GitTestHelper.run(["commit", "-m", "B edits README"], at: cloneB)
        try GitTestHelper.run(["push"], at: cloneB)

        try "User A version\n".write(
            to: cloneA.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneA, message: "A edits README")

        // Pull should throw .conflict
        await #expect(throws: GitClientError.conflict) {
            try await client.pull(at: cloneA)
        }

        // After abort, the repo should be back to A's commit (clean state)
        let changes = try await client.pendingChanges(at: cloneA)
        #expect(changes.isEmpty)
    }

    // MARK: - Branch operations

    @Test func currentBranchOnMain() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        let branch = try await client.currentBranch(at: cloneDir)
        #expect(branch.isMain)
        #expect(branch.name == "main" || branch.name == "master")
    }

    @Test func createBranchAndSwitch() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Create and switch to new branch
        try await client.createBranch(named: "noteblob/test-branch", at: cloneDir)

        let branch = try await client.currentBranch(at: cloneDir)
        #expect(branch.name == "noteblob/test-branch")
        #expect(!branch.isMain)

        // Files should still be there
        #expect(
            FileManager.default.fileExists(
                atPath: cloneDir.appendingPathComponent("README.md").path))
    }

    @Test func switchBranch() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Create branch, then switch back to main
        try await client.createBranch(named: "feature", at: cloneDir)
        let featureBranch = try await client.currentBranch(at: cloneDir)
        #expect(featureBranch.name == "feature")

        try await client.switchBranch(to: "main", at: cloneDir)
        let mainBranch = try await client.currentBranch(at: cloneDir)
        #expect(mainBranch.isMain)
    }

    @Test func deleteBranch() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Create branch, switch back to main, then delete branch
        try await client.createBranch(named: "to-delete", at: cloneDir)
        try await client.switchBranch(to: "main", at: cloneDir)
        try await client.deleteBranch(named: "to-delete", at: cloneDir)

        // Verify branch is gone by checking git CLI
        let branches = try GitTestHelper.run(["branch"], at: cloneDir)
        #expect(!branches.contains("to-delete"))
    }

    @Test func hasUpstreamOnMain() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Main should have upstream after clone
        let hasUpstream = try await client.hasUpstream(at: cloneDir)
        #expect(hasUpstream)
    }

    // MARK: - Discard changes

    @Test func discardChangesRevertsModifiedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        let readmePath = cloneDir.appendingPathComponent("README.md")
        let original = try String(contentsOf: readmePath, encoding: .utf8)

        // Modify the file
        try "Modified content\n".write(to: readmePath, atomically: true, encoding: .utf8)
        let changes = try await client.pendingChanges(at: cloneDir)
        #expect(!changes.isEmpty)

        // Discard
        try await client.discardChanges(at: cloneDir)

        let restored = try String(contentsOf: readmePath, encoding: .utf8)
        #expect(restored == original)

        let afterDiscard = try await client.pendingChanges(at: cloneDir)
        #expect(afterDiscard.isEmpty)
    }

    @Test func discardChangesRemovesUntrackedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Add an untracked file
        let newFile = cloneDir.appendingPathComponent("untracked.md")
        try "new file\n".write(to: newFile, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: newFile.path))

        // Discard
        try await client.discardChanges(at: cloneDir)

        #expect(!FileManager.default.fileExists(atPath: newFile.path))

        let afterDiscard = try await client.pendingChanges(at: cloneDir)
        #expect(afterDiscard.isEmpty)
    }

    @Test func discardChangesHandlesDeletedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Delete a tracked file
        let readmePath = cloneDir.appendingPathComponent("README.md")
        try FileManager.default.removeItem(at: readmePath)
        #expect(!FileManager.default.fileExists(atPath: readmePath.path))

        // Discard
        try await client.discardChanges(at: cloneDir)

        // File should be restored
        #expect(FileManager.default.fileExists(atPath: readmePath.path))

        let afterDiscard = try await client.pendingChanges(at: cloneDir)
        #expect(afterDiscard.isEmpty)
    }

    @Test func discardChangesCleansMultipleMixedChanges() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Modify existing file
        try "changed\n".write(
            to: cloneDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        // Add new file
        try "new\n".write(
            to: cloneDir.appendingPathComponent("new.md"), atomically: true, encoding: .utf8)
        // Stage some changes
        try GitTestHelper.run(["add", "new.md"], at: cloneDir)

        let changes = try await client.pendingChanges(at: cloneDir)
        #expect(changes.count >= 2)

        // Discard everything
        try await client.discardChanges(at: cloneDir)

        let afterDiscard = try await client.pendingChanges(at: cloneDir)
        #expect(afterDiscard.isEmpty)
        #expect(
            !FileManager.default.fileExists(atPath: cloneDir.appendingPathComponent("new.md").path))
    }

    @Test func discardSingleModifiedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Add a second file and commit it
        try "second\n".write(
            to: cloneDir.appendingPathComponent("second.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add second")

        // Modify both files
        try "changed readme\n".write(
            to: cloneDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "changed second\n".write(
            to: cloneDir.appendingPathComponent("second.md"), atomically: true, encoding: .utf8)

        let changes = try await client.pendingChanges(at: cloneDir)
        #expect(changes.count == 2)

        // Discard only README.md
        try await client.discardChange(at: cloneDir, path: "README.md")

        let afterDiscard = try await client.pendingChanges(at: cloneDir)
        #expect(afterDiscard.count == 1)
        #expect(afterDiscard.first?.path == "second.md")

        let readme = try String(
            contentsOf: cloneDir.appendingPathComponent("README.md"), encoding: .utf8)
        #expect(readme == "# Test Repo\n")
    }

    @Test func discardSingleUntrackedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Add two untracked files
        try "a\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "b\n".write(
            to: cloneDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)

        // Discard only a.md
        try await client.discardChange(at: cloneDir, path: "a.md")

        #expect(
            !FileManager.default.fileExists(atPath: cloneDir.appendingPathComponent("a.md").path))
        #expect(
            FileManager.default.fileExists(atPath: cloneDir.appendingPathComponent("b.md").path))
    }

    @Test func discardChangesIsNoOpWhenClean() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // No changes — should not throw
        try await client.discardChanges(at: cloneDir)

        let changes = try await client.pendingChanges(at: cloneDir)
        #expect(changes.isEmpty)
    }

    // MARK: - Diff

    @Test func diffModifiedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Modify the README
        try "Modified content\n".write(
            to: cloneDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let fileDiff = try await client.diff(at: cloneDir, path: "README.md")
        #expect(fileDiff.path == "README.md")
        #expect(!fileDiff.hunks.isEmpty)

        let lines = fileDiff.hunks.flatMap(\.lines)
        let additions = lines.filter { $0.kind == .addition }
        let deletions = lines.filter { $0.kind == .deletion }
        #expect(!additions.isEmpty)
        #expect(!deletions.isEmpty)
        #expect(additions.contains { $0.content.contains("Modified content") })
    }

    @Test func diffAddedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Create a new file
        try "Brand new file\n".write(
            to: cloneDir.appendingPathComponent("new.md"), atomically: true, encoding: .utf8)

        let fileDiff = try await client.diff(at: cloneDir, path: "new.md")
        #expect(fileDiff.path == "new.md")
        #expect(!fileDiff.hunks.isEmpty)

        let lines = fileDiff.hunks.flatMap(\.lines)
        #expect(lines.allSatisfy { $0.kind == .addition })
        #expect(lines.contains { $0.content.contains("Brand new file") })
    }

    @Test func diffDeletedFile() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Delete the tracked file
        try FileManager.default.removeItem(at: cloneDir.appendingPathComponent("README.md"))

        let fileDiff = try await client.diff(at: cloneDir, path: "README.md")
        #expect(fileDiff.path == "README.md")
        // Deleted files may return empty hunks (SwiftGitX patch limitation for .deleted deltas)
        // but the path should still be correct
        if !fileDiff.hunks.isEmpty {
            let lines = fileDiff.hunks.flatMap(\.lines)
            #expect(lines.allSatisfy { $0.kind == .deletion })
        }
    }

    // MARK: - Upstream

    @Test func hasUpstreamOnNewBranch() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // New local branch has no upstream
        try await client.createBranch(named: "local-only", at: cloneDir)
        let before = try await client.hasUpstream(at: cloneDir)
        #expect(!before)

        // After push, upstream should be set
        try "new\n".write(
            to: cloneDir.appendingPathComponent("new.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "commit on branch")
        try await client.push(at: cloneDir)

        let after = try await client.hasUpstream(at: cloneDir)
        #expect(after)
    }

    // MARK: - Fetch

    @Test func fetchNoChanges() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Fetch when nothing changed — should not throw
        try await client.fetch(at: cloneDir)

        let changes = try await client.pendingChanges(at: cloneDir)
        #expect(changes.isEmpty)
    }

    @Test func fetchPicksUpRemoteChanges() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)

        let cloneA = baseDir.appendingPathComponent("clone-a")
        try await client.clone(remoteURL: remoteURL, to: cloneA)

        // Second user pushes a commit
        let cloneB = baseDir.appendingPathComponent("clone-b")
        try GitTestHelper.clone(remote: remoteURL, to: cloneB, in: baseDir)
        try "from B\n".write(
            to: cloneB.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try GitTestHelper.run(["add", "."], at: cloneB)
        try GitTestHelper.run(["commit", "-m", "B commit"], at: cloneB)
        try GitTestHelper.run(["push"], at: cloneB)

        // Before fetch, A doesn't know about B's commit
        let (_, behindBefore) = try await client.aheadBehind(at: cloneA)
        #expect(behindBefore == 0)

        // After fetch, A sees it is behind
        try await client.fetch(at: cloneA)
        let (_, behindAfter) = try await client.aheadBehind(at: cloneA)
        #expect(behindAfter == 1)
    }

    // MARK: - Ahead/Behind edge cases

    @Test func aheadBehindAheadOnly() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Make two local commits without pushing
        try "a\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "first local")
        try "b\n".write(
            to: cloneDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "second local")

        let (ahead, behind) = try await client.aheadBehind(at: cloneDir)
        #expect(ahead == 2)
        #expect(behind == 0)
    }

    @Test func aheadBehindDiverged() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)

        let cloneA = baseDir.appendingPathComponent("clone-a")
        try await client.clone(remoteURL: remoteURL, to: cloneA)

        // Second user pushes
        let cloneB = baseDir.appendingPathComponent("clone-b")
        try GitTestHelper.clone(remote: remoteURL, to: cloneB, in: baseDir)
        try "from B\n".write(
            to: cloneB.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try GitTestHelper.run(["add", "."], at: cloneB)
        try GitTestHelper.run(["commit", "-m", "B commit"], at: cloneB)
        try GitTestHelper.run(["push"], at: cloneB)

        // A makes a local commit (diverging from remote)
        try "from A\n".write(
            to: cloneA.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneA, message: "A commit")

        // Fetch so A knows about B's commit
        try await client.fetch(at: cloneA)

        let (ahead, behind) = try await client.aheadBehind(at: cloneA)
        #expect(ahead == 1)
        #expect(behind == 1)
    }

    // MARK: - Log

    @Test func logReturnsCommitHistory() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Make two more commits
        try "a\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add a.md")
        try "b\n".write(
            to: cloneDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add b.md")

        let commits = try await client.log(at: cloneDir, options: LogOptions(limit: 10))
        #expect(commits.count == 3)  // initial + 2
        // Most recent first
        #expect(commits[0].message == "Add b.md")
        #expect(commits[1].message == "Add a.md")
        #expect(commits[2].message == "Initial commit")
    }

    @Test func logRespectsLimitParameter() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        try "a\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add a.md")
        try "b\n".write(
            to: cloneDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add b.md")

        let commits = try await client.log(at: cloneDir, options: LogOptions(limit: 2))
        #expect(commits.count == 2)
        #expect(commits[0].message == "Add b.md")
        #expect(commits[1].message == "Add a.md")
    }

    @Test func logFiltersByPath() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Commit touching a.md
        try "a\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add a.md")

        // Commit touching b.md only
        try "b\n".write(
            to: cloneDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add b.md")

        // Commit touching a.md again
        try "a updated\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Update a.md")

        let commits = try await client.log(
            at: cloneDir, options: LogOptions(limit: 10, path: "a.md"))
        #expect(commits.count == 2)
        #expect(commits[0].message == "Update a.md")
        #expect(commits[1].message == "Add a.md")
    }

    @Test func logDownToRefExcludesOlderCommits() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Create a branch point
        try await client.createBranch(named: "feature", at: cloneDir)

        // Make commits on the feature branch
        try "a\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Feature commit 1")
        try "b\n".write(
            to: cloneDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Feature commit 2")

        // Log only commits since main — should exclude Initial commit
        let commits = try await client.log(
            at: cloneDir, options: LogOptions(limit: 10, downToRef: "main"))
        #expect(commits.count == 2)
        #expect(commits[0].message == "Feature commit 2")
        #expect(commits[1].message == "Feature commit 1")
    }

    @Test func logCommitInfoHasIdAndDate() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        let commits = try await client.log(at: cloneDir, options: LogOptions(limit: 1))
        #expect(commits.count == 1)

        let commit = commits[0]
        // Short hash should be 7 characters
        #expect(commit.id.count == 7)
        // Date should be recent (within last minute)
        #expect(commit.date.timeIntervalSinceNow > -60)
    }

    @Test func logReturnsChangedFiles() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        try "a\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add a.md")

        try "b\n".write(
            to: cloneDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try "a updated\n".write(
            to: cloneDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try await client.commitAll(at: cloneDir, message: "Add b.md and update a.md")

        let commits = try await client.log(
            at: cloneDir, options: LogOptions(limit: 10, uniqueFilesLimit: 10))
        #expect(commits[0].changedFiles.sorted() == ["a.md", "b.md"])
        #expect(commits[1].changedFiles == ["a.md"])
    }

    @Test func logStopsAtUniqueFilesLimit() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        // Create 3 commits each touching a different file
        for name in ["a.md", "b.md", "c.md"] {
            try "\(name)\n".write(
                to: cloneDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
            try await client.commitAll(at: cloneDir, message: "Add \(name)")
        }

        // Request only 2 unique files — should stop early
        let commits = try await client.log(at: cloneDir, options: LogOptions(uniqueFilesLimit: 2))
        let allFiles = Set(commits.flatMap(\.changedFiles))
        #expect(allFiles.count >= 2)
        // Should have fewer commits than total (4 = initial + 3)
        #expect(commits.count < 4)
    }

    // MARK: - Branch error paths

    @Test func switchToNonExistentBranchThrows() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        await #expect(throws: (any Error).self) {
            try await client.switchBranch(to: "nonexistent", at: cloneDir)
        }

        // Should still be on main
        let branch = try await client.currentBranch(at: cloneDir)
        #expect(branch.isMain)
    }

    @Test func createDuplicateBranchThrows() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        try await client.createBranch(named: "feature", at: cloneDir)
        try await client.switchBranch(to: "main", at: cloneDir)

        await #expect(throws: (any Error).self) {
            try await client.createBranch(named: "feature", at: cloneDir)
        }
    }

    // MARK: - Diff edge cases

    @Test func diffUnchangedFileReturnsEmptyHunks() async throws {
        let baseDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let (_, remoteURL) = try createBareRemote(in: baseDir)
        let cloneDir = baseDir.appendingPathComponent("client-clone")
        try await client.clone(remoteURL: remoteURL, to: cloneDir)

        let fileDiff = try await client.diff(at: cloneDir, path: "README.md")
        #expect(fileDiff.path == "README.md")
        #expect(fileDiff.hunks.isEmpty)
    }
}
