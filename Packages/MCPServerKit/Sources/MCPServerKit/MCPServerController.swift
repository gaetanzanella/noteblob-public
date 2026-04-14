import Foundation

public enum MCPServerStatus: Sendable, Equatable {
    case stopped
    case starting
    case running
    case failed(String)
}

public protocol MCPServerController: Sendable {
    var status: MCPServerStatus { get async }
    var statusStream: AsyncStream<MCPServerStatus> { get async }
    func startHTTPServer(port: UInt16) async throws
    func stop() async
}
