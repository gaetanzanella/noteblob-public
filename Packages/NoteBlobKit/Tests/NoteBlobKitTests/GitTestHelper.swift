import Foundation

enum GitTestHelper {

    @discardableResult
    static func run(_ args: [String], at dir: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output =
            String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "git", code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "git \(args.joined(separator: " ")) failed: \(output)"
                ])
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func configureUser(at dir: URL) throws {
        try run(["config", "user.email", "test@test.com"], at: dir)
        try run(["config", "user.name", "Test"], at: dir)
    }

    /// Creates a bare repo with an initial commit containing a README.md.
    /// Returns the path to `remote.git` inside `baseDir`.
    static func createBareRemote(in baseDir: URL) throws -> URL {
        let workDir = baseDir.appendingPathComponent("init-work")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        try run(["init"], at: workDir)
        try configureUser(at: workDir)
        try "# Test Repo\n".write(
            to: workDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try run(["add", "."], at: workDir)
        try run(["commit", "-m", "Initial commit"], at: workDir)

        let bareDir = baseDir.appendingPathComponent("remote.git")
        try run(["clone", "--bare", workDir.path, bareDir.path], at: baseDir)
        try FileManager.default.removeItem(at: workDir)

        return bareDir
    }

    /// Clones the bare remote using git CLI and configures user identity.
    static func clone(remote: String, to dir: URL, in baseDir: URL) throws {
        try run(["clone", remote, dir.path], at: baseDir)
        try configureUser(at: dir)
    }
}
