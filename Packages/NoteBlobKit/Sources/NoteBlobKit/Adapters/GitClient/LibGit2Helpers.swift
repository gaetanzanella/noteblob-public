import libgit2

/// Checks a libgit2 return code, throwing a descriptive error on failure.
func gitCheck(_ result: Int32) throws {
    guard result >= 0 else {
        if result == GIT_EAUTH.rawValue {
            throw GitClientError.authenticationFailed
        }
        let error = git_error_last()
        let message =
            error.flatMap { String(cString: $0.pointee.message) } ?? "Unknown libgit2 error"
        throw GitClientError.commandFailed(
            command: "libgit2", output: "\(message) (code: \(result))")
    }
}
