import Foundation

public struct Folder: Sendable, Identifiable, Hashable, Codable {

    enum Source: Sendable, Codable, Hashable {
        case github(Repository)
        case local(name: String)
    }

    let source: Source

    public var id: String {
        switch source {
        case .github(let repository): return "\(repository.owner)/\(repository.name)"
        case .local(let name): return "local/\(name)"
        }
    }

    public var name: String {
        switch source {
        case .github(let repository): return repository.name
        case .local(let name): return name
        }
    }

    public var isGitBacked: Bool {
        if case .github = source { return true }
        return false
    }

    var repository: Repository? {
        if case .github(let repo) = source { return repo }
        return nil
    }

    init(repository: Repository) {
        self.source = .github(repository)
    }

    public init(localName: String) {
        self.source = .local(name: localName)
    }
}
