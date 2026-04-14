import Foundation

enum MCPToolError: LocalizedError {
    case missingParameter(String)
    case folderNotFound(String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let name):
            return "Missing required parameter: \(name)"
        case .folderNotFound(let id):
            return "Folder not found: \(id). Use list_folders to see available folders."
        }
    }
}
