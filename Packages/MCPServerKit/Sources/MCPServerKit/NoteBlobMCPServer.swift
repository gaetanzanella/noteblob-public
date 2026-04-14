import Foundation
import MCP

public final class NoteBlobMCPServer: MCPServerController, Sendable {

    private let handler: NoteToolHandler
    private let encoder: JSONEncoder
    private let state = ServerState()

    public init(adapter: NoteBlobAdapter) {
        self.handler = NoteToolHandler(adapter: adapter)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        self.encoder = encoder
    }

    public var status: MCPServerStatus {
        get async { await state.status }
    }

    public var statusStream: AsyncStream<MCPServerStatus> {
        get async { await state.stream }
    }

    public func startHTTPServer(port: UInt16) async throws {
        #if os(macOS)
        await state.transition(to: .starting)

        let transport = StatelessHTTPServerTransport(
            validationPipeline: StandardValidationPipeline(validators: [])
        )
        let listener: HTTPListener
        do {
            listener = try HTTPListener(port: port, transport: transport)
            try await listener.start()
        } catch {
            await state.transition(to: .failed(error.localizedDescription))
            throw error
        }
        await state.setListener(listener)

        let server = await configureServer()
        do {
            try await server.start(transport: transport)
        } catch {
            await state.transition(to: .failed(error.localizedDescription))
            throw error
        }

        await state.transition(to: .running)
        #endif
    }

    public func stop() async {
        #if os(macOS)
        await state.stop()
        #endif
    }

    /// Starts the MCP server on the given transport. Blocks until disconnect.
    func startServer(on transport: any Transport) async throws {
        let server = await configureServer()
        try await server.start(transport: transport)
    }

    // MARK: - Private

    private func configureServer() async -> Server {
        let server = Server(
            name: "noteblob",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        let handler = self.handler
        let encoder = self.encoder

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: ToolDefinitions.all)
        }

        await server.withMethodHandler(CallTool.self) { params in
            await route(params, handler: handler, encoder: encoder)
        }

        return server
    }
}

// MARK: - Server State

private actor ServerState {
    private(set) var status: MCPServerStatus = .stopped
    private var continuations: [UUID: AsyncStream<MCPServerStatus>.Continuation] = [:]
    #if os(macOS)
    private var listener: HTTPListener?
    #endif

    var stream: AsyncStream<MCPServerStatus> {
        let (stream, continuation) = AsyncStream<MCPServerStatus>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.removeContinuation(id) }
        }
        continuation.yield(status)
        return stream
    }

    func transition(to newStatus: MCPServerStatus) {
        status = newStatus
        for continuation in continuations.values {
            continuation.yield(newStatus)
        }
    }

    func stop() {
        #if os(macOS)
        listener?.stop()
        listener = nil
        #endif
        transition(to: .stopped)
    }

    #if os(macOS)
    func setListener(_ listener: HTTPListener) {
        self.listener = listener
    }
    #endif

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

// MARK: - Routing

private func route(
    _ params: CallTool.Parameters,
    handler: NoteToolHandler,
    encoder: JSONEncoder
) async -> CallTool.Result {
    do {
        switch params.name {
        case "list_repositories":
            return try encode(handler.listRepositories(ListRepositoriesInput(arguments: params.arguments)), encoder: encoder)
        case "search_notes":
            return try await encode(handler.searchNotes(SearchNotesInput(arguments: params.arguments)), encoder: encoder)
        default:
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    } catch {
        return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
    }
}

private func encode<T: Encodable>(_ value: T, encoder: JSONEncoder) throws -> CallTool.Result {
    let data = try encoder.encode(value)
    let text = String(data: data, encoding: .utf8) ?? "[]"
    return .init(content: [.text(text)])
}
