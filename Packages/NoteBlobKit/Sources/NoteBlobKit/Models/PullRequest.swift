import Foundation

public struct PullRequest: Sendable {
    public let number: Int
    public let htmlURL: String

    public init(number: Int, htmlURL: String) {
        self.number = number
        self.htmlURL = htmlURL
    }
}
