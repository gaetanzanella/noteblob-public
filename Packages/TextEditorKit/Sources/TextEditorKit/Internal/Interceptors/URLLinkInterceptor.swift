import Foundation

// MARK: - URLLinkInterceptor

/// When the user pastes an HTTP(S) URL while a non-empty selection is active,
/// wraps the selection as a markdown link: `[selection](url)`.
///
/// The bracket-wrap interceptor handles typed opening characters; this one
/// handles the specific paste-over-selection case for URLs — a common
/// shortcut to turn some highlighted text into a hyperlink.
struct URLLinkInterceptor: TypeInterceptor {

    var priority: Int { 10 }

    func intercept(_ context: TypeContext) -> TextEdit? {
        let selected = context.replacedText
        guard !selected.isEmpty else { return nil }
        guard let url = Self.normalizedURL(context.replacementString) else { return nil }

        // UIKit already replaced the selection with the URL. Re-replace that
        // range with `[selection](url)` and leave the caret right after the
        // closing paren.
        let replacementStart = context.changedRange.lowerBound
        let urlLength = url.utf16.count
        let replacementRange = replacementStart..<(replacementStart + urlLength)
        let markdown = "[\(selected)](\(url))"
        let caret = replacementStart + markdown.utf16.count
        return TextEdit(
            changes: [.replace(range: replacementRange, with: markdown)],
            selection: caret..<caret
        )
    }

    /// Returns the string as-is if it's a clean single-line HTTP(S) URL;
    /// otherwise nil.
    private static func normalizedURL(_ raw: String) -> String? {
        guard !raw.contains("\n"), !raw.contains(" ") else { return nil }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        guard url.host?.isEmpty == false else { return nil }
        return raw
    }
}
