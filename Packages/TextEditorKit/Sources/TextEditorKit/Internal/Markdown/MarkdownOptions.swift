import Markdown

extension ParseOptions {

    /// Single source of truth for how this app parses markdown.
    /// `.disableSmartOpts` keeps `--`/`---` as literal dashes — otherwise the
    /// parser silently rewrites them to en/em dashes and table separators
    /// like `|---|---|` fall back to plain paragraphs on round-trip.
    static var documentDefault: ParseOptions {
        .disableSmartOpts
    }
}

extension MarkupFormatter.Options {

    /// Single source of truth for how this app formats markdown. Both
    /// `FormatActionHandler` (format-document) and `TableActionHandler`
    /// (insert table) round-trip through these options, so a freshly
    /// inserted table is a no-op for format-document.
    static var documentDefault: MarkupFormatter.Options {
        MarkupFormatter.Options(
            unorderedListMarker: .dash,
            orderedListNumerals: .incrementing(start: 1)
        )
    }
}
