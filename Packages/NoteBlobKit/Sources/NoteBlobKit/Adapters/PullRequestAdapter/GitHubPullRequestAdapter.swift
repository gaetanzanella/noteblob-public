import Foundation

final class GitHubPullRequestAdapter: PullRequestAdapter, @unchecked Sendable {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - List

    func listPullRequests(_ request: ListPullRequestsRequest) async throws -> [PullRequest] {
        let head = "\(request.owner):\(request.head)"
        let encoded = head.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? head
        let url = URL(string: "https://api.github.com/repos/\(request.owner)/\(request.repo)/pulls?head=\(encoded)&state=open")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        applyHeaders(&urlRequest, token: request.credentials.token)

        let (data, response) = try await session.data(for: urlRequest)
        try checkResponse(response, data: data)

        let items = try JSONDecoder().decode([GitHubPR].self, from: data)
        return items.map { PullRequest(number: $0.number, htmlURL: $0.html_url) }
    }

    // MARK: - Create

    func createPullRequest(_ request: CreatePullRequestRequest) async throws -> PullRequest {
        let url = URL(string: "https://api.github.com/repos/\(request.owner)/\(request.repo)/pulls")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        applyHeaders(&urlRequest, token: request.credentials.token)
        urlRequest.httpBody = try JSONEncoder().encode(
            CreatePRBody(title: request.title, head: request.head, base: request.base)
        )

        let (data, response) = try await session.data(for: urlRequest)
        try checkResponse(response, data: data)

        let pr = try JSONDecoder().decode(GitHubPR.self, from: data)
        return PullRequest(number: pr.number, htmlURL: pr.html_url)
    }

    // MARK: - Merge

    func mergePullRequest(_ request: MergePullRequestRequest) async throws {
        let url = URL(string: "https://api.github.com/repos/\(request.owner)/\(request.repo)/pulls/\(request.number)/merge")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        applyHeaders(&urlRequest, token: request.credentials.token)
        urlRequest.httpBody = try JSONEncoder().encode(
            MergePRBody(merge_method: "rebase")
        )

        let (data, response) = try await session.data(for: urlRequest)
        try checkResponse(response, data: data)
    }

    // MARK: - Private

    private func applyHeaders(_ request: inout URLRequest, token: String) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitClientError.apiError(statusCode: 0, message: "Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitClientError.apiError(statusCode: http.statusCode, message: message)
        }
    }
}

// MARK: - DTOs

private struct GitHubPR: Decodable {
    let number: Int
    let html_url: String
}

private struct CreatePRBody: Encodable {
    let title: String
    let head: String
    let base: String
}

private struct MergePRBody: Encodable {
    let merge_method: String
}
