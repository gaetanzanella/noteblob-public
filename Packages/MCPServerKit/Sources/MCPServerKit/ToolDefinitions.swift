import MCP

enum ToolDefinitions {
    static var all: [Tool] {
        [
            Tool(
                name: "list_repositories",
                description: "List all note repositories managed by NoteBlob, with their local filesystem paths",
                inputSchema: .object([:])
            ),
            Tool(
                name: "search_notes",
                description: "Search notes by content or filename within a repository",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "repository_id": .object([
                            "type": .string("string"),
                            "description": .string("The repository ID (from list_repositories)")
                        ]),
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Search query to match against note content and filenames")
                        ])
                    ]),
                    "required": .array([.string("repository_id"), .string("query")])
                ])
            ),
        ]
    }
}
