import Foundation

enum GitClientError: Error, LocalizedError, Equatable {
    case commandFailed(command: String, output: String)
    case apiError(statusCode: Int, message: String)
    case missingMetadata
    case conflict
    case noDiff
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let output):
            return "git \(command) failed: \(output)"
        case .apiError(let statusCode, let message):
            return "GitHub API error (\(statusCode)): \(message)"
        case .missingMetadata:
            return "Local repository metadata not found"
        case .conflict:
            return "Merge conflict detected. Resolve conflicts before continuing."
        case .noDiff:
            return "No changes between branches."
        case .authenticationFailed:
            return "Authentication failed. Please sign in again."
        }
    }
}
