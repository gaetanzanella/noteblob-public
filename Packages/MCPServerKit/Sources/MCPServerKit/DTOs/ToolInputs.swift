import MCP

struct ListRepositoriesInput {
    init(arguments: [String: Value]?) {}
}

struct SearchNotesInput {
    let repositoryID: String
    let query: String

    init(arguments: [String: Value]?) throws {
        guard let repositoryID = arguments?["repository_id"]?.stringValue else {
            throw MCPToolError.missingParameter("repository_id")
        }
        guard let query = arguments?["query"]?.stringValue else {
            throw MCPToolError.missingParameter("query")
        }
        self.repositoryID = repositoryID
        self.query = query
    }
}
