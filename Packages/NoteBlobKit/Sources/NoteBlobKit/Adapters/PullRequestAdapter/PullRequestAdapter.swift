import Foundation

struct ListPullRequestsRequest: Sendable {
    let owner: String
    let repo: String
    let head: String
    let credentials: Credentials
}

struct CreatePullRequestRequest: Sendable {
    let owner: String
    let repo: String
    let head: String
    let base: String
    let title: String
    let credentials: Credentials
}

struct MergePullRequestRequest: Sendable {
    let owner: String
    let repo: String
    let number: Int
    let credentials: Credentials
}

struct DeleteBranchRequest: Sendable {
    let owner: String
    let repo: String
    let branch: String
    let credentials: Credentials
}

protocol PullRequestAdapter: Sendable {
    func listPullRequests(_ request: ListPullRequestsRequest) async throws -> [PullRequest]
    func createPullRequest(_ request: CreatePullRequestRequest) async throws -> PullRequest
    func mergePullRequest(_ request: MergePullRequestRequest) async throws
    func deleteRemoteBranch(_ request: DeleteBranchRequest) async throws
}
