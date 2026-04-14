import Foundation
import NoteBlobKit

enum ErrorMapper {

    static func errorDescription(for error: Error) -> String {
        guard let noteBlobError = error as? NoteBlobError else {
            return error.localizedDescription
        }
        switch noteBlobError {
        case .notAuthenticated:
            return String(localized: "error.not_authenticated", bundle: .module)
        case .conflict:
            return String(localized: "error.conflict", bundle: .module)
        case .syncFailed(let message):
            return String(localized: "error.sync_failed \(message)", bundle: .module)
        case .mergeConflict(let prURL):
            return String(localized: "error.merge_conflict \(prURL)", bundle: .module)
        case .invalidOperation(let message):
            return String(localized: "error.invalid_operation \(message)", bundle: .module)
        }
    }
}
