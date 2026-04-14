import Foundation
import FoundationModels

final class NativeLLMAdapter: LLMRepository, Sendable {

    func isAvailable() async -> Bool {
        SystemLanguageModel.default.isAvailable
    }

    func generateText(prompt: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
