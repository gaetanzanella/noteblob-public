import Foundation

struct Repository: Sendable, Codable, Hashable {
    let owner: String
    let name: String
}
