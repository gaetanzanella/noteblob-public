import Foundation

// MARK: - MarkdownLineToken

/// Represents the block-level markdown element for a line.
/// Provides a stable API that hides the swift-markdown implementation details.
enum MarkdownLineToken: Sendable, Equatable {
    case paragraph
    case heading(level: Int)
    case codeBlock(language: String?, isFenced: Bool)
    case blockQuote(depth: Int)
    case listItem(ListItemInfo)
    case thematicBreak
    case table(TableInfo)
    case htmlBlock

    /// Information about a list item
    struct ListItemInfo: Sendable, Equatable {
        let isOrdered: Bool
        let depth: Int
        let marker: String
        let checkbox: Checkbox?
        let number: Int?
        /// UTF-16 length of the full prefix (indentation + marker + checkbox + space)
        let prefixLength: Int

        enum Checkbox: Sendable, Equatable {
            case checked
            case unchecked
        }

        init(
            isOrdered: Bool, depth: Int, marker: String, checkbox: Checkbox? = nil,
            number: Int? = nil, prefixLength: Int = 0
        ) {
            self.isOrdered = isOrdered
            self.depth = depth
            self.marker = marker
            self.checkbox = checkbox
            self.number = number
            self.prefixLength = prefixLength
        }

        /// Returns the prefix for continuing this list
        func continuationPrefix() -> String {
            var prefix = String(repeating: "  ", count: depth)

            if isOrdered {
                let nextNumber = (number ?? 0) + 1
                prefix += "\(nextNumber). "
            } else {
                prefix += "- "
            }

            if checkbox != nil {
                prefix += "[ ] "
            }

            return prefix
        }
    }

    /// Information about a table block — the parsed cells plus the 0-based
    /// line range the table occupies in the document.
    struct TableInfo: Sendable, Equatable {
        let headers: [String]
        let rows: [[String]]
        let lineRange: Range<Int>

        init(headers: [String], rows: [[String]], lineRange: Range<Int>) {
            self.headers = headers
            self.rows = rows
            self.lineRange = lineRange
        }
    }
}

// MARK: - MarkdownInlineToken

/// Represents inline markdown formatting at a specific position.
/// Used to detect active formatting state for toolbar buttons.
public struct MarkdownInlineToken: Sendable, Equatable, OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let bold = MarkdownInlineToken(rawValue: 1 << 0)
    public static let italic = MarkdownInlineToken(rawValue: 1 << 1)
    public static let strikethrough = MarkdownInlineToken(rawValue: 1 << 2)
    public static let inlineCode = MarkdownInlineToken(rawValue: 1 << 3)
    public static let link = MarkdownInlineToken(rawValue: 1 << 4)
    public static let image = MarkdownInlineToken(rawValue: 1 << 5)
}
