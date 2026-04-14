import Foundation

struct GitHubRepositoryURLProvider: RepositoryURLProvider {
    func remoteURL(for folder: Folder, credentials: Credentials) -> String {
        guard let repository = folder.repository else { return "" }
        return "https://\(credentials.token)@github.com/\(repository.owner)/\(repository.name).git"
    }
}
