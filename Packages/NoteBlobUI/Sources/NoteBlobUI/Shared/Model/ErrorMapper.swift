import Foundation
import NoteBlobKit

enum ErrorMapper {

    static func errorDescription(for error: Error) -> AttributedString {
        guard let noteBlobError = error as? NoteBlobError else {
            return AttributedString(error.localizedDescription)
        }
        switch noteBlobError {
        case .notAuthenticated:
            return AttributedString(localized: "error.not_authenticated", bundle: .module)
        case .conflict:
            return AttributedString(localized: "error.conflict", bundle: .module)
        case .syncFailed(let message):
            return AttributedString(localized: "error.sync_failed \(message)", bundle: .module)
        case .mergeConflict(let prURL):
            var result = AttributedString(localized: "error.merge_conflict \(prURL)", bundle: .module)
            if let url = URL(string: prURL), let range = result.range(of: prURL) {
                result[range].link = url
            }
            return result
        case .invalidOperation(let message):
            return AttributedString(localized: "error.invalid_operation \(message)", bundle: .module)
        case .folderAlreadyInstalled:
            return AttributedString(localized: "error.folder_already_installed", bundle: .module)
        }
    }
}
