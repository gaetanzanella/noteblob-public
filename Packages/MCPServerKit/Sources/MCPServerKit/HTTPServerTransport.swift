#if os(macOS)
import Foundation
import MCP
import Network
import Synchronization

protocol HTTPRequestHandler: Sendable {
    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse
}

extension StatelessHTTPServerTransport: HTTPRequestHandler {}
extension StatefulHTTPServerTransport: HTTPRequestHandler {}

/// A minimal HTTP listener that bridges NWListener to MCP's HTTP server transports.
public final class HTTPListener: @unchecked Sendable {

    private let port: UInt16
    private let handler: any HTTPRequestHandler
    private let listener: NWListener
    private let listenerQueue = DispatchQueue.main

    init(port: UInt16 = 9100, transport: some HTTPRequestHandler & Transport) throws {
        self.port = port
        self.handler = transport
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
    }

    public func start() async throws {
        listener.newConnectionHandler = { [self] connection in
            self.handleConnection(connection)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumed = Mutex(false)
            listener.stateUpdateHandler = { state in
                let alreadyResumed = resumed.withLock { val -> Bool in
                    if val { return true }
                    val = true
                    return false
                }
                guard !alreadyResumed else { return }
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    resumed.withLock { $0 = false }
                }
            }
            listener.start(queue: listenerQueue)
        }
    }

    public func stop() {
        listener.cancel()
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        let queue = DispatchQueue(label: "mcp.connection.\(UUID().uuidString)")
        connection.start(queue: queue)
        queue.async { [self] in
            self.receiveData(connection: connection, buffer: Data())
        }
    }

    private func receiveData(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self else { return }

            guard let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            var buffer = buffer
            buffer.append(data)

            guard let parsed = RawHTTPRequest(data: buffer) else {
                self.receiveData(connection: connection, buffer: buffer)
                return
            }

            if !parsed.isComplete {
                self.receiveData(connection: connection, buffer: buffer)
                return
            }

            let httpRequest = HTTPRequest(
                method: parsed.method,
                headers: parsed.headers,
                body: parsed.body.isEmpty ? nil : parsed.body,
                path: parsed.path
            )

            Task { @Sendable in
                let response = await self.handler.handleRequest(httpRequest)
                self.sendHTTPResponse(connection: connection, response: response)
            }
        }
    }

    private func sendHTTPResponse(connection: NWConnection, response: HTTPResponse) {
        let statusLine: String
        switch response.statusCode {
        case 200: statusLine = "HTTP/1.1 200 OK"
        case 202: statusLine = "HTTP/1.1 202 Accepted"
        case 400: statusLine = "HTTP/1.1 400 Bad Request"
        case 404: statusLine = "HTTP/1.1 404 Not Found"
        case 405: statusLine = "HTTP/1.1 405 Method Not Allowed"
        default: statusLine = "HTTP/1.1 \(response.statusCode) Error"
        }

        let body = response.bodyData ?? Data()
        var headerLines = response.headers.map { "\($0.key): \($0.value)" }
        headerLines.append("Content-Length: \(body.count)")
        headerLines.append("Connection: close")
        headerLines.append("Access-Control-Allow-Origin: *")
        headerLines.append("Access-Control-Allow-Methods: POST, OPTIONS")
        headerLines.append("Access-Control-Allow-Headers: Content-Type, Accept, Mcp-Session-Id, MCP-Protocol-Version")

        let head = ([statusLine] + headerLines).joined(separator: "\r\n") + "\r\n\r\n"
        var responseData = head.data(using: .utf8)!
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

// MARK: - HTTP Parser (CFHTTPMessage)

struct RawHTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
    let isComplete: Bool

    init?(data: Data) {
        let message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true).takeRetainedValue()
        CFHTTPMessageAppendBytes(message, (data as NSData).bytes.assumingMemoryBound(to: UInt8.self), data.count)

        guard CFHTTPMessageIsHeaderComplete(message) else { return nil }

        self.method = CFHTTPMessageCopyRequestMethod(message)?.takeRetainedValue() as String? ?? ""
        let url = CFHTTPMessageCopyRequestURL(message)?.takeRetainedValue() as URL?
        self.path = url?.path ?? "/"
        self.body = CFHTTPMessageCopyBody(message)?.takeRetainedValue() as Data? ?? Data()

        var headers: [String: String] = [:]
        if let cfHeaders = CFHTTPMessageCopyAllHeaderFields(message)?.takeRetainedValue() as? [String: String] {
            headers = cfHeaders
        }
        self.headers = headers

        let contentLength = headers.first { $0.key.lowercased() == "content-length" }
            .flatMap { Int($0.value) } ?? 0
        self.isComplete = body.count >= contentLength
    }
}
#endif
