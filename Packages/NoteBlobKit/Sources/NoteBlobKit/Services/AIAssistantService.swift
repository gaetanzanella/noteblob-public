import Foundation

public final class AIAssistantService: Sendable {

    private let llmRepository: LLMRepository

    init(llmRepository: LLMRepository) {
        self.llmRepository = llmRepository
    }

    public func isAvailable() async -> Bool {
        await llmRepository.isAvailable()
    }

    public func generateCommitMessage(for changes: [Change]) async throws -> String {
        let prompt = buildPrompt(for: changes)
        let message = try await llmRepository.generateText(prompt: prompt)
        return "[noteblob] \(message)"
    }

    private func buildPrompt(for changes: [Change]) -> String {
        let descriptions = changes.map { change in
            let name = URL(fileURLWithPath: change.path).deletingPathExtension().lastPathComponent
            switch change {
            case .added: return "\(name) (added)"
            case .modified: return "\(name) (modified)"
            case .deleted: return "\(name) (deleted)"
            }
        }

        return """
            Summarize these changes into a short commit message (max 20 chars): \(descriptions.joined(separator: ", ")).
            Only output the message, nothing else.
            """
    }
}
