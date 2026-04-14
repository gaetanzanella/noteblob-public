import Foundation
import Testing
import MCP

@testable import MCPServerKit

struct MCPServerTests {

    private let testRepo = MCPRepository(id: "local/test-folder", name: "test-folder", path: "/tmp/test/local/test-folder")

    private let searchResults: [MCPSearchResult] = [
        MCPSearchResult(name: "hello.md", path: "hello.md", isFolder: false, snippet: "hello world")
    ]

    private func makeConnectedClient() async throws -> Client {
        let adapter = MockNoteBlobAdapter(
            repositories: [testRepo],
            searchResults: searchResults
        )
        let server = NoteBlobMCPServer(adapter: adapter)

        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        Task { try await server.startServer(on: serverTransport) }

        let client = Client(name: "test", version: "1.0.0")
        try await client.connect(transport: clientTransport)
        return client
    }

    // MARK: - Protocol

    @Test func listToolsReturnsTwoTools() async throws {
        let client = try await makeConnectedClient()
        let (tools, _) = try await client.listTools()

        #expect(tools.count == 2)
        let names = Set(tools.map(\.name))
        #expect(names == ["list_repositories", "search_notes"])
    }

    // MARK: - Tools

    @Test func listRepositoriesReturnsPathAndName() async throws {
        let client = try await makeConnectedClient()
        let (content, isError) = try await client.callTool(name: "list_repositories")

        #expect(isError != true)
        let text = extractText(from: content)
        #expect(text.contains("test-folder"))
        #expect(text.contains("path"))
    }

    @Test func searchNotesReturnsResults() async throws {
        let client = try await makeConnectedClient()
        let (content, isError) = try await client.callTool(
            name: "search_notes",
            arguments: [
                "repository_id": .string(testRepo.id),
                "query": .string("hello")
            ]
        )

        #expect(isError != true)
        let text = extractText(from: content)
        #expect(text.contains("hello.md"))
        #expect(text.contains("hello world"))
    }

    // MARK: - Errors

    @Test func unknownRepositoryReturnsError() async throws {
        let client = try await makeConnectedClient()
        let (content, isError) = try await client.callTool(
            name: "search_notes",
            arguments: [
                "repository_id": .string("nonexistent"),
                "query": .string("test")
            ]
        )
        #expect(isError == true)
        let text = extractText(from: content)
        #expect(text.contains("Folder not found"))
    }

    @Test func missingRequiredParamReturnsError() async throws {
        let client = try await makeConnectedClient()
        let (content, isError) = try await client.callTool(
            name: "search_notes",
            arguments: [:]
        )
        #expect(isError == true)
        let text = extractText(from: content)
        #expect(text.contains("Missing required parameter"))
    }

    // MARK: - Utility

    private func extractText(from content: [Tool.Content]) -> String {
        content.compactMap { item in
            if case .text(let text, _, _) = item { return text }
            return nil
        }.joined()
    }
}
