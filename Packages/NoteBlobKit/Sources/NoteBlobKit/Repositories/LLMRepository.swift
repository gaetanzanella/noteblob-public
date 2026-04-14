import Foundation

protocol LLMRepository: Sendable {
    func isAvailable() async -> Bool
    func generateText(prompt: String) async throws -> String
}
