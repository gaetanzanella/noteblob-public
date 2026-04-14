import Foundation

struct RepositoryOutput: Encodable {
    let id: String
    let name: String
    let path: String
}

struct SearchResultOutput: Encodable {
    let name: String
    let path: String
    let type: String
    let snippet: String?
}
