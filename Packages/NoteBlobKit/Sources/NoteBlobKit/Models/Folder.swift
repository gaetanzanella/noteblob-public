import Foundation

public struct Folder: Sendable, Identifiable, Hashable, Codable {

    enum Source: Sendable, Codable, Hashable {
        case github(Repository, defaultBranch: String)
        case local(name: String)
    }

    let source: Source

    public var id: String {
        switch source {
        case .github(let repository, _): return "\(repository.owner)/\(repository.name)"
        case .local(let name): return "local/\(name)"
        }
    }

    public var name: String {
        switch source {
        case .github(let repository, _): return repository.name
        case .local(let name): return name
        }
    }

    public var isGitBacked: Bool {
        if case .github = source { return true }
        return false
    }

    public var defaultBranch: String? {
        if case .github(_, let branch) = source { return branch }
        return nil
    }

    public var repository: Repository? {
        if case .github(let repo, _) = source { return repo }
        return nil
    }

    public func isDefault(_ branch: BranchInfo) -> Bool {
        branch.name == defaultBranch
    }

    public init(repository: Repository, defaultBranch: String) {
        self.source = .github(repository, defaultBranch: defaultBranch)
    }

    public init(localName: String) {
        self.source = .local(name: localName)
    }
}
