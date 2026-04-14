import Foundation

// MARK: - MarkdownLineToken

/// Represents the block-level markdown element for a line.
/// Provides a stable API that hides the swift-markdown implementation details.
public enum MarkdownLineToken: Sendable, Equatable {
    case paragraph
    case heading(level: Int)
    case codeBlock(language: String?, isFenced: Bool)
    case blockQuote(depth: Int)
    case listItem(ListItemInfo)
    case thematicBreak
    case table
    case htmlBlock

    /// Information about a list item
    public struct ListItemInfo: Sendable, Equatable {
        public let isOrdered: Bool
        public let depth: Int
        public let marker: String
        public let checkbox: Checkbox?
        public let number: Int?
        /// UTF-16 length of the full prefix (indentation + marker + checkbox + space)
        public let prefixLength: Int

        public enum Checkbox: Sendable, Equatable {
            case checked
            case unchecked
        }

        public init(
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
        public func continuationPrefix() -> String {
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
