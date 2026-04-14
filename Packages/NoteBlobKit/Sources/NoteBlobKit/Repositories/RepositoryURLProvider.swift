import Foundation

public protocol RepositoryURLProvider: Sendable {
    func remoteURL(for folder: Folder, credentials: Credentials) -> String
}
